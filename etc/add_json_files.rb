require 'xcodeproj'
project = Xcodeproj::Project.open('swift-bson.xcodeproj')
targets = project.native_targets

# make a file reference for the provided project with file at dirPath (relative)
def make_reference(project, path)
    fileRef = project.new(Xcodeproj::Project::Object::PBXFileReference)
    fileRef.path = path
    return fileRef
end

swiftbson_tests_target = targets.find { |t| t.uuid == "swift-bson::BSONTests" }
corpus = make_reference(project, "./Tests/Specs/bson-corpus")
swiftbson_tests_target.add_resources([corpus])

project.save
