Pod::Spec.new do |s|
  s.name = 'InterviewNativeKit'
  s.version = '0.0.1'
  s.summary = 'Local TurboModule and Fabric demo for RN interview app'
  s.homepage = 'https://example.com/interview-native-kit'
  s.license = { :type => 'MIT' }
  s.authors = { 'TRAE' => 'support@example.com' }
  s.platforms = { :ios => '15.1' }
  s.source = { :git => 'https://example.com/interview-native-kit.git', :tag => s.version.to_s }
  s.source_files = 'ios/**/*.{h,m,mm}'
  s.requires_arc = true

  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20',
    'HEADER_SEARCH_PATHS' => '"$(inherited)" "$(PODS_ROOT)/Headers/Private/Yoga" "$(PODS_ROOT)/Headers/Private/React-Fabric" "$(PODS_ROOT)/Headers/Private/React-RCTFabric"'
  }

  s.dependency 'React-Core'
  s.dependency 'React-Fabric'
  s.dependency 'React-RCTFabric'
  s.dependency 'ReactCodegen'
  s.dependency 'React-NativeModulesApple'
  s.dependency 'ReactCommon/turbomodule/core'
  s.dependency 'Yoga'
end
