#
# Be sure to run `pod lib lint ResourceLoaderCache.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ResourceLoaderCache'
  s.version          = '0.0.1'
  s.summary          = 'ResourceLoading and cache written in Swift.'

  s.homepage         = 'https://github.com/codeXH/ResourceLoaderCache'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'codeXH' => 'wo18919029008@163.com' }
  s.source           = { :git => 'https://github.com/codeXH/ResourceLoaderCache.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'

  s.source_files = 'ResourceLoaderCache/Classes/**/*'
end
