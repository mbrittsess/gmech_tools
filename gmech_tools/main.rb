require 'sketchup.rb'

require 'gmech_tools/base_metadata.rb'
require 'gmech_tools/camera_metadata.rb'

TestBarMeta = GmkSpatialMetadataBase.new (
    :model => 'gmech_tools/models/Bar.skp',
    :internal_name => 'TestBarMeta',
    :friendly_name => 'Bar'
)

TestFooMeta = GmkSpatialMetadataBase.new (
    :model => 'gmech_tools/models/Foo.skp',
    :internal_name => 'TestFooMeta',
    :friendly_name => 'Foo'
)

SpawnOfsMeta = GmkSpatialMetadataBase.new (
    :model => 'gmech_tools/models/SpawnOfs.skp',
    :internal_name => 'SpawnOfsMeta',
    :friendly_name => 'Spawn Offset'
)

BasicCameraViewpoint = GmkCameraMetadataBase.new (
    :model => 'gmech_tools/models/Camera_43_90deg.skp',
    :internal_name => 'BasicCameraViewpointMeta',
    :friendly_name => 'Basic Camera Viewpoint'
)