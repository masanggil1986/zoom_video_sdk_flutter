import Cocoa
import FlutterMacOS
import ZMVideoSDK

/// Flutter `AppKitView` factory — creates NSViews that render a user's
/// video or share canvas via Zoom Video SDK.
///
/// Expected args (creationParams as `[String: Any]`):
/// - `userId`: ZMVideoSDKUser ID
/// - `kind`: "video" (default) or "share"
final class ZoomVideoPlatformViewFactory: NSObject, FlutterPlatformViewFactory {

    static let viewTypeId = "zoom_video_sdk_flutter/video_view"

    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
        let params = (args as? [String: Any]) ?? [:]
        let userId = params["userId"] as? String ?? ""
        let kindStr = params["kind"] as? String ?? "video"
        let kind: ZoomVideoViewKind = (kindStr == "share") ? .share : .video
        return ZoomVideoRenderView(userId: userId, kind: kind)
    }

    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

enum ZoomVideoViewKind {
    case video
    case share
}

/// Describes the canvas methods we need to invoke. We never directly
/// reference `ZMVideoSDKVideoCanvas` or `ZMVideoSDKShareAction` because
/// the SDK binary does not export their Obj-C class symbols — the linker
/// would fail. Declaring the selectors here with matching `@objc` names
/// lets Swift dispatch via `objc_msgSend` on `AnyObject` without needing
/// the class symbol at link time.
@objc private protocol _ZoomCanvasMethods {
    @objc(subscribeWithView:aspectMode:resolution:)
    func subscribeWithView(_ view: NSView,
                           aspectMode: UInt,
                           resolution: UInt) -> UInt

    @objc(unSubscribeWithView:)
    func unSubscribeWithView(_ view: NSView) -> UInt
}

/// NSView that holds a subscription to a Zoom video/share canvas.
///
/// The canvas is resolved lazily — on first `layout()` and whenever video
/// status changes — so the view works even if the user or video isn't
/// available at construction time.
final class ZoomVideoRenderView: NSView {

    /// 사용자 상태(session join, user join, video on/off, share start/stop) 변화 시
    /// 플러그인이 게시하는 알림. 아직 subscribe 하지 못한 view들이 재시도하기 위함.
    static let userStateChangedNotification = Notification.Name(
        "ZoomVideoRenderView.userStateChanged"
    )

    private let userId: String
    private let kind: ZoomVideoViewKind

    /// The canvas we last subscribed to (typed as NSObject; see protocol comment).
    private var subscribedCanvas: NSObject?
    private var isSubscribed = false

    /// Pending retry work after an async subscribe failure.
    /// Canceled on unsubscribe/deinit/new successful subscribe.
    private var pendingRetry: DispatchWorkItem?

    /// 구독 실패 후 재시도 백오프. _Auto/_720P 실패가 limit 계열이면 360P로 폴백.
    private var fallbackResolution: UInt?

    init(userId: String, kind: ZoomVideoViewKind) {
        self.userId = userId
        self.kind = kind
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserStateChanged),
            name: Self.userStateChangedNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            subscribeIfPossible()
        } else {
            unsubscribe()
        }
    }

    override func layout() {
        super.layout()
        // Retry subscription once we have non-zero size — Zoom SDK ignores
        // subscribe on a view with CGSize.zero on some releases.
        if bounds.width > 0, bounds.height > 0 {
            subscribeIfPossible()
        }
    }

    /// 사용자 상태 이벤트(session join, user join, video on/off, share start/stop) 도착 시
    /// 항상 subscribe 점검을 실행. 첫 시도 때 user/canvas가 없어 silent fail 한 경우는
    /// 물론, 사용자가 비디오를 토글하거나 share를 다시 시작하여 canvas 객체가 교체된
    /// 경우(기존 구독이 dead canvas에 묶여 검은 화면이 되는 케이스)에도 대응한다.
    @objc private func handleUserStateChanged() {
        guard window != nil else { return }
        subscribeIfPossible()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        pendingRetry?.cancel()
        unsubscribe()
    }

    // MARK: - Subscription

    /// 대상 user의 현재 canvas에 subscribe 한 상태가 되도록 조정한다.
    /// - 동일 canvas에 이미 subscribe → no-op
    /// - 다른 canvas로 바뀐 경우 (예: 사용자가 비디오/share 재시작) → 기존 구독 해제 후 재구독
    /// - canvas가 사라진 경우 (예: 비디오 off, share stop) → 기존 구독 해제만
    /// 즉, 호출이 idempotent 하고 canvas-ware 하므로 어떤 이벤트 시점에 호출해도 안전.
    func subscribeIfPossible() {
        // Zero-bounds에서 subscribe 하면 일부 SDK 릴리즈에서 sync Success만 리턴하고
        // 실제 스트림은 시작되지 않아 검은 화면으로 남음. 명시적으로 거부하고 layout()이
        // 비-zero 바운드로 재호출해 주길 기다린다.
        guard bounds.width > 0, bounds.height > 0 else { return }
        guard let session = ZMVideoSDK.shared().getSessionInfo() else { return }

        let myself = session.getMySelf()
        let isMyself = (myself?.getID() ?? "") == userId

        // 자신이 공유 중인 화면은 렌더링하지 않음 (Windows와 동작 일치).
        // Windows에서는 로컬 share pipe subscribe 시 SDK 종료 크래시가 발생해 skip 하고,
        // macOS에서는 안전하긴 하지만 UX 관점에서 동일하게 본인 share 타일은 검은 배경 유지.
        if kind == .share, isMyself { return }

        let user: ZMVideoSDKUser? = isMyself
            ? myself
            : session.getRemoteUsers()?.first { ($0.getID() ?? "") == userId }

        let canvas: NSObject? = {
            guard let user else { return nil }
            return switch kind {
            case .video: Self.resolveVideoCanvas(for: user)
            case .share: Self.resolveShareCanvas(for: user)
            }
        }()

        // 동일 canvas에 이미 subscribe → 그대로 둔다.
        if let canvas, let existing = subscribedCanvas, existing === canvas, isSubscribed {
            return
        }

        // canvas 가 변했거나 사라졌다면 기존 구독을 먼저 해제.
        if subscribedCanvas != nil {
            unsubscribe()
        }

        guard let canvas else { return }

        let typed = unsafeBitCast(canvas, to: _ZoomCanvasMethods.self)
        // video는 view 크기 기반 자동 해상도(_Auto)를 사용 — 갤러리 형태로 다수 타일을
        // 동시에 띄울 때 SDK가 720P 스트림을 일부 silent drop 하는 현상을 회피.
        // share는 _Auto 미지원이라 720P 유지. 이전 구독이 limit 계열로 실패했다면
        // fallbackResolution(360P)로 낮춰서 재시도.
        let resolution: UInt = fallbackResolution ?? (kind == .video
            ? UInt(ZMVideoSDKResolution_Auto.rawValue)
            : UInt(ZMVideoSDKResolution_720P.rawValue))
        let err = typed.subscribeWithView(
            self,
            aspectMode: UInt(ZMVideoSDKVideoAspect_Original.rawValue),
            resolution: resolution
        )
        NSLog("[ZoomVideoView] subscribe userId=\(userId) kind=\(kind) res=\(resolution) bounds=\(bounds.size) err=\(err)")
        if err == UInt(ZMVideoSDKErrors_Success.rawValue) {
            subscribedCanvas = canvas
            isSubscribed = true
            pendingRetry?.cancel()
            pendingRetry = nil
        }
    }

    func unsubscribe() {
        pendingRetry?.cancel()
        pendingRetry = nil
        guard let canvas = subscribedCanvas else { return }
        let typed = unsafeBitCast(canvas, to: _ZoomCanvasMethods.self)
        _ = typed.unSubscribeWithView(self)
        subscribedCanvas = nil
        isSubscribed = false
    }

    /// SDK가 `onVideoCanvasSubscribeFail` / `onShareCanvasSubscribeFail`로
    /// 비동기 구독 실패를 알려주는 경우 호출된다.
    /// - sync subscribe는 Success를 반환했지만 실제 스트림이 연결되지 못한 상태 →
    ///   우리가 캐싱한 `subscribedCanvas`/`isSubscribed`도 함께 리셋해야 한다.
    /// - 이후 backoff 후 재시도. limit 계열 실패면 360P로 폴백.
    func handleSubscribeFailure(reason: ZMVideoSDKSubscribeFailReason) {
        NSLog("[ZoomVideoView] subscribe FAILED (async) userId=\(userId) kind=\(kind) reason=\(reason.rawValue)")
        subscribedCanvas = nil
        isSubscribed = false

        let isLimit = reason != ZMVideoSDKSubscribeFailReason_TooFrequentCall
            && reason != ZMVideoSDKSubscribeFailReason_None
        if isLimit, kind == .video {
            fallbackResolution = UInt(ZMVideoSDKResolution_360P.rawValue)
        }

        pendingRetry?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingRetry = nil
            self?.subscribeIfPossible()
        }
        pendingRetry = work
        // TooFrequentCall이 주로 다수 타일 동시 subscribe에서 발생하므로
        // 짧은 랜덤 지터로 뷰 간 재시도 타이밍을 분산.
        let base: TimeInterval = reason == ZMVideoSDKSubscribeFailReason_TooFrequentCall ? 0.4 : 0.8
        let jitter = Double.random(in: 0...0.3)
        DispatchQueue.main.asyncAfter(deadline: .now() + base + jitter, execute: work)
    }

    // MARK: - KVC bridges (class symbols not exported)

    private static func resolveVideoCanvas(
        for user: ZMVideoSDKUser
    ) -> NSObject? {
        let sel = NSSelectorFromString("getVideoCanvas")
        guard user.responds(to: sel) else { return nil }
        return user.perform(sel)?.takeUnretainedValue() as? NSObject
    }

    private static func resolveShareCanvas(
        for user: ZMVideoSDKUser
    ) -> NSObject? {
        let listSel = NSSelectorFromString("getShareActionList")
        guard user.responds(to: listSel),
              let raw = user.perform(listSel)?.takeUnretainedValue() as? NSArray,
              let firstAction = raw.firstObject as? NSObject else {
            return nil
        }
        let canvasSel = NSSelectorFromString("getShareCanvas")
        guard firstAction.responds(to: canvasSel) else { return nil }
        return firstAction.perform(canvasSel)?.takeUnretainedValue() as? NSObject
    }
}
