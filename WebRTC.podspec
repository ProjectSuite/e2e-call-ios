Pod::Spec.new do |s|
  s.name             = 'WebRTC'
  s.version          = '1.7.0'
  s.summary          = 'WebRTC iOS XCFramework with customize audio encode/decode'
  s.homepage         = 'https://webrtc.googlesource.com/src'

  # FIX: Removed ":file => 'LICENSE'" so it doesn't crash if the file is missing in the zip
  s.license          = { :type => 'BSD', :text => 'WebRTC License: https://webrtc.org/license' }

  s.author           = { 'airfeed' => 'admin.airfeed@kbinvt.com' }
  s.platform         = :ios, '11.0'
  s.swift_version    = '5.0'

  s.source = {
    :http => 'https://github.com/techhubcloud/webrtc-ios/releases/download/1.7.0/WebRTC.xcframework.zip?raw=1'
  }


  s.vendored_frameworks = 'WebRTC.xcframework'
  s.public_header_files = 'WebRTC.xcframework/**/*.framework/Headers/*.h'
  s.static_framework = true

  s.frameworks = %w(
    AVFoundation
    CoreMedia
    CoreVideo
    VideoToolbox
    AudioToolbox
  )
end
