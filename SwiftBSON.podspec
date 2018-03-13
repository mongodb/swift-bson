Pod::Spec.new do |spec|
  spec.name             = "SwiftBSON"
  spec.version          = "0.0.1"
  spec.summary          = "Swift bindings for libbson"
  spec.homepage         = "https://github.com/10gen/swift-bson"
  spec.license          = "Apache License 2.0"
  spec.author           = { "mbroadst" => "mbroadst@mongodb.com" }
  spec.source           = { :git => "ssh://git@github.com/10gen/swift-bson.git", :branch => "master" }

  spec.osx.deployment_target = '10.9'
  spec.swift_version = '4.0'
  spec.requires_arc = true

  spec.module_name = "libbson"
  spec.preserve_path = "module.modulemap"
  spec.module_map = "module.modulemap"
end
