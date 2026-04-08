#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint zoom_video_sdk_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'zoom_video_sdk_flutter'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for Zoom Video SDK (macOS).'
  s.description      = <<-DESC
Flutter plugin wrapping the Zoom Video SDK for macOS.
Download the ZoomVideoSDK.xcframework from Zoom Marketplace
and place it in macos/Frameworks/ before building.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*.swift'

  s.vendored_frameworks = Dir['Frameworks/*.framework']
  s.vendored_libraries  = Dir['Frameworks/lib*.dylib', 'Frameworks/VideoSDK.dylib']
  s.resources           = Dir['Frameworks/*.bundle', 'Frameworks/*.app']
  s.preserve_paths      = 'Frameworks/**'

  # VideoSDK.dylib는 lib 접두사가 없어 vendored_libraries로 처리 불가 — 직접 링크
  s.user_target_xcconfig = {
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/../Frameworks',
  }

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}/../.symlinks/plugins/zoom_video_sdk_flutter/macos/Frameworks" "${PODS_TARGET_SRCROOT}/Frameworks"',
    'LIBRARY_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}/../.symlinks/plugins/zoom_video_sdk_flutter/macos/Frameworks" "${PODS_TARGET_SRCROOT}/Frameworks" "${BUILT_PRODUCTS_DIR}"',
    'OTHER_LDFLAGS' => '$(inherited)',
    'SWIFT_INCLUDE_PATHS' => '$(inherited) "${PODS_ROOT}/../.symlinks/plugins/zoom_video_sdk_flutter/macos/Frameworks" "${PODS_TARGET_SRCROOT}/Frameworks"',
  }
  s.swift_version = '5.0'
end
