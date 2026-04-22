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

    private let userId: String
    private let kind: ZoomVideoViewKind

    /// The canvas we last subscribed to (typed as NSObject; see protocol comment).
    private var subscribedCanvas: NSObject?
    private var isSubscribed = false

    init(userId: String, kind: ZoomVideoViewKind) {
        self.userId = userId
        self.kind = kind
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
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
        if !isSubscribed, bounds.width > 0, bounds.height > 0 {
            subscribeIfPossible()
        }
    }

    deinit {
        unsubscribe()
    }

    // MARK: - Subscription

    func subscribeIfPossible() {
        guard !isSubscribed else { return }
        let sdk = ZMVideoSDK.shared()
        guard let session = sdk.getSessionInfo() else { return }

        let user: ZMVideoSDKUser? = {
            if let myself = session.getMySelf(),
               (myself.getID() ?? "") == userId {
                return myself
            }
            return session.getRemoteUsers()?.first { ($0.getID() ?? "") == userId }
        }()
        guard let user else { return }

        let canvas: NSObject? = switch kind {
        case .video: Self.resolveVideoCanvas(for: user)
        case .share: Self.resolveShareCanvas(for: user)
        }
        guard let canvas else { return }

        let typed = unsafeBitCast(canvas, to: _ZoomCanvasMethods.self)
        let err = typed.subscribeWithView(
            self,
            aspectMode: UInt(ZMVideoSDKVideoAspect_Original.rawValue),
            resolution: UInt(ZMVideoSDKResolution_720P.rawValue)
        )
        if err == UInt(ZMVideoSDKErrors_Success.rawValue) {
            subscribedCanvas = canvas
            isSubscribed = true
        }
    }

    func unsubscribe() {
        guard isSubscribed, let canvas = subscribedCanvas else { return }
        let typed = unsafeBitCast(canvas, to: _ZoomCanvasMethods.self)
        _ = typed.unSubscribeWithView(self)
        subscribedCanvas = nil
        isSubscribed = false
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
