# Base class metadata has a model, an internal name,
# and a friendly name, and exports only position and
# orientation.

require 'sketchup.rb'
require 'gmech_tools/lua_helper.rb'

class GmkSpatialMetadataBase
    
    attr_reader :definition, :internal_name, :friendly_name, :full_path
    
    #Set up GMech menu with which we add spawn-items
    tools_menu = UI.menu( 'Tools' )
    tools_menu.add_separator( )
    @@spawn_menu = tools_menu.add_submenu( 'Add GMech Metadata' )
    @@internal2meta = Hash.new( )

    #'param' is a hashtable used for named parameters.
    def initialize ( param )
        relative_path = 'plugins/' + param[ :model ]
        @full_path = Sketchup.find_support_file( relative_path )
            if not @full_path then
                raise ArgumentError, ( "Couldn't find model at '%s'" % relative_path )
            end
            
        self.reload_definition( )
        
        @internal_name = param[ :internal_name ]
        @friendly_name = param[ :friendly_name ]
        
        @@internal2meta[ @internal_name ] = self
        
        self.set_up_initialization_callback( )
        self.set_up_context_menu_callback( )
        self.set_up_reload_callback( )
        
        #Add menu item for spawning
        @@spawn_menu.add_item( @friendly_name ) do
            self.spawn( )
        end
    end
    
    def reload_definition ( )
        @definition = Sketchup.active_model.definitions.load( @full_path )
            if not @definition then
                raise ArgumentError, ( "Couldn't load component from '%s'" % relative_path )
            end
    end
    
    def spawn ( )
        Sketchup.active_model.place_component( @definition, false )
    end
    
    def set_up_initialization_callback ( )
        @definition.add_observer( GmkSpatialMetadataBase_DefinitionObserver.new( self ) )
    end
    
    def set_up_reload_callback ( )
        Sketchup.add_observer( GmkSpatialMetadataBase_AppObserver.new( self ) )
    end
    
    def initialize_metadata ( inst, default_dict )
        default_dict[ 'internal_name' ] = @internal_name
        default_dict[ 'friendly_name' ] = @friendly_name
        #UI.messagebox( "You placed a %s (%s)!" % [ @friendly_name, @internal_name ] )
    end
    
    def set_up_context_menu_callback ( )
        UI.add_context_menu_handler do | menu |
            curr_selection = Sketchup.active_model.selection
            if curr_selection.single_object? then
                entity = curr_selection.first
                dict = entity.attribute_dictionary( 'GMechMetadata', false )
                if dict and ( dict[ 'internal_name' ] == @internal_name ) then
                    self.on_right_click( entity, menu )
                end
            end
        end
    end
    
    def on_right_click ( inst, menu )
        menu.add_separator( )
        menu.add_item( "SURPRISE" ) do
            UI.messagebox( "You right-clicked on a %s (%s)!" % [ @friendly_name, @internal_name ] )
        end
        #if self.respond_to?( :edit_metadata ) then
        #   menu.add_item( "Edit GMech Metadata..." ) do
        #       self.edit_metadata( inst, inst.attribute_dictionary( 'GMechMetadata', false ) )
        #   end
        #end
        menu.add_item( "See export data..." ) do
            UI.messagebox( self.export_metadata( inst, inst.attribute_dictionary( 'GMechMetadata', false ) ) )
        end
    end
    
    #Optionally defined:
    #def edit_metadata ( inst, default_dict )
    #   
    #end
    
    def export_metadata ( inst, default_dict )
        exp = LuaExportHelper.new( )
        exp.add_array_part( default_dict[ 'internal_name' ].enquote_lua_long() )
        
        pos = inst.transformation.origin
        pos_s = "Vector( %.6f, %.6f, %.6f )" % pos.to_a()
        
        ang = inst.transformation.to_qangle()
        ang_s = "Angle( %.6f, %.6f, %.6f )" % ang
        
        exp.add_record_part( "Position", pos_s )
        exp.add_record_part( "Angle", ang_s )
        return exp.export()
    end
    
    #Global metadata-export function
    def self.export_metadata( path )
        out_buf = [ "return {" ]
        
        Sketchup.active_model.definitions.each do | definition | definition.instances.each do | instance |
            default_dict = instance.attribute_dictionary( 'GMechMetadata', false )
            if default_dict then
                internal_name = default_dict[ 'internal_name' ]
                meta = @@internal2meta[ internal_name ]
                if meta then
                    out_buf.push( meta.export_metadata( instance, default_dict ) + ';' )
                end
            end
        end end
        
        out_buf.push( '}' )
        
        final_out = out_buf.join( "\n" )
        UI.messagebox( final_out )
        
        file = File.new( path, "w" )
        if not file then
            raise IOError, ( "Couldn't create/open file '%s'" % path )
        end
        
        file.write( final_out )
        file.close()
    end
    
  #NON-CLASS SETUP
    #Create "Export Metadata..." item
    tools_menu.add_item( "Export Metadata..." ) {
        model_dict = Sketchup.active_model.attribute_dictionary( 'GMechMetadata', true )
        
        #exist_path = model_dict[ 'SavePath' ]
        #exist_name = model_dict[ 'SaveName' ]
        exist_path = nil
        exist_name = nil
        
        model_path = Sketchup.active_model.path
        model_name = Sketchup.active_model.name
        
        default_path = "C:/"
        default_name = "default"
        
        save_path = if exist_path then
            exist_path
        elsif not model_path.empty? then    
            model_path
        else
            default_path
        end
        
        save_name = if exist_name then
            exist_name
        elsif not model_name.empty? then
            model_name
        else
            default_name
        end
        
        final_path = UI.savepanel(
            "Save Metadata",
            save_path,
            save_name + '.txt'
        )
        
        if final_path then #User did choose a location
            GmkSpatialMetadataBase.export_metadata( final_path )
        end
    }
end

class GmkSpatialMetadataBase_DefinitionObserver < Sketchup::DefinitionObserver
    def initialize ( meta )
        @meta = meta
    end
    
    def onComponentInstanceAdded ( definition, instance )
        if definition == @meta.definition then
            default_dict = instance.attribute_dictionary( 'GMechMetadata', true )
            @meta.initialize_metadata( instance, default_dict )
        end
    end
end

class GmkSpatialMetadataBase_AppObserver < Sketchup::AppObserver
    def initialize ( meta )
        @meta = meta
    end
    
    def onNewModel ( model )
        @meta.reload_definition( )
    end
    
    def onOpenModel ( model )
        @meta.reload_definition( )
    end
end

class Geom::Transformation
    def to_qangle ( )
        # SketchUp uses OpenGL matrix storage, so:
        #  0  4  8 12
        #  1  5  9 13
        #  2  6 10 14
        #  3  7 11 15
        trans = self.to_a( )
        return [
            #Source Angles are pitch, yaw, roll; rotations around Y, Z, and X, respectively
            Math::atan2(
                -trans[2],
                Math::sqrt( (trans[6] ** 2) + (trans[10] ** 2) ) ).degrees(),
            Math::atan2(
                trans[1],
                trans[0] ).degrees(),
            Math::atan2(
                trans[6],
                trans[10] ).degrees()
        ]
    end
end