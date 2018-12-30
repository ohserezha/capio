# Uncomment this line to define a global platform for your project
# platform :ios, '9.0'

target 'capio' do
  # Comment this line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!
  platform :ios, '4.2'
  pod 'MotionAnimation', :git => 'https://github.com/lkzhao/MotionAnimation.git', :branch => 'swift3'
  pod 'ElasticTransition', :git => 'https://github.com/lkzhao/ElasticTransition.git', :branch => 'swift3'
  pod 'JQSwiftIcon', :git => 'https://github.com/ronanamsterdam/JQSwiftIcon.git', :branch => '_rz-to-swift3'
  pod 'BRYXBanner', :git => 'https://github.com/bryx-inc/BRYXBanner', :branch => 'master'
  pod 'ScalePicker', :git => 'https://github.com/ronanamsterdam/ScalePicker.git', :branch => '_rz-will-value-change'

  pod 'CariocaMenu', :git => 'https://github.com/ronanamsterdam/cariocamenu.git', :branch => '_rz-blur-shape'

  pod 'RxSwift', :git => 'https://github.com/ReactiveX/RxSwift'
  pod 'RxCocoa', :git => 'https://github.com/ReactiveX/RxSwift'


  # Pods for capio

  target 'capioTests' do
    inherit! :search_paths
    # Pods for testing
    pod 'RxBlocking', :git => 'https://github.com/ReactiveX/RxSwift'
    pod 'RxTest',     :git => 'https://github.com/ReactiveX/RxSwift'
  end

  target 'capioUITests' do
    inherit! :search_paths
    # Pods for testing
  end

end
