require 'extensions'

gmech_tools_extensions = SketchupExtension.new( 'GMech Tools', 'gmech_tools/main.rb' )

gmech_tools_extensions.creator = 'Matthew Britton Sessions'
gmech_tools_extensions.description = 'Tools for use with creating models for GMech'

Sketchup.register_extension( gmech_tools_extensions, false )