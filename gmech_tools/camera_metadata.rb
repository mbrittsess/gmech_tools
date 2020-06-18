# This adds no new properties or such for
# camera metadata, but implements a context-menu
# option "assume view" that aligns one's view
# with the given camera.

require 'sketchup.rb'
require 'gmech_tools/base_metadata.rb'

class GmkCameraMetadataBase < GmkSpatialMetadataBase
    Default_hFOV = 90.0
    Default_AR  = 4.0 / 3.0
    Forward_Vec = Geom::Vector3d.new( 1.0, 0.0, 0.0 )
    Up_Vec      = Geom::Vector3d.new( 0.0, 0.0, 1.0 )
    
    def on_right_click ( instance, menu )
        super( instance, menu )
        
        menu.add_item( "Assume view" ) do
            self.assume_view( instance )
        end
    end
    
    def assume_view ( instance )
        trans = instance.transformation
        view_origin = trans.origin
        
        #It turns out SketchUp 2013, at least, DOES take a nominal hFOV for a 4:3 monitor...I think.
        vFOV = ( 2.0 * Math::atan( Math::tan( Default_hFOV.degrees / 2.0 ) / Default_AR ) ).radians
        
        own_cam = Sketchup::Camera.new(
            view_origin,
            trans * Forward_Vec,
            trans * Up_Vec,
            true,
            Default_hFOV
        )
        
        own_cam.aspect_ratio = Default_AR
        
        view = Sketchup.active_model.active_view
        
        view.camera = own_cam
    end
    
    tools_menu = UI.menu( 'Tools' )
    tools_menu.add_item( 'Restore camera (temp)' ) do
        puts "Restoring camera"
        camera = Sketchup.active_model.active_view.camera
        camera.aspect_ratio = 0.0
        camera.fov = 30.0
        camera.perspective = true
    end
end