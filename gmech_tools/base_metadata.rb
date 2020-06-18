# Base class metadata has a model, an internal name,
# and a friendly name, and exports only position and
# orientation.

require 'sketchup.rb'
require 'gmech_tools/lua_helper.rb'

class GmkSpatialMetadataBase
  #Class Setup
  public
    @@internal2meta = Hash.new( ) #Also functions as the repository of all meta-objects
    @@path2internal = Hash.new( ) #Just here to prevent definition-collisions
    
    def self.register_metadata ( meta_object )
        internal_name = meta_object.internal_name
        full_path     = meta_object.full_path
        
        existing_internal_from_path = @@path2internal[ full_path ]
        if existing_internal_from_path and ( existing_internal_from_path != internal_name ) then
            raise ArgumentError, ( "Cannot use component at '%s' for '%s', that component is already used by '%s'" %
                [ full_path, internal_name, existing_internal_from_path ] )
        end
        
        @@internal2meta[ internal_name ] = meta_object
        @@path2internal[ full_path ] = internal_name
    end
    
    def self.lookup_meta ( internal_name )
        if not @@internal2meta[ internal_name ] then
            raise ArgumentError, ( "No such metadata '%s'" % internal_name )
        end
        
        return @@internal2meta[ internal_name ]
    end
    
    def self.each_metadata ( &block )
        @@internal2meta.each_value( &block )
    end
    
  protected
    def self.set_up_initialization_callback ( meta )
        meta.definition.add_observer( GmkSpatialMetadataBase_DefinitionObserver.new( meta ) )
    end
    
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
    
    tools_menu = UI.menu( 'Tools' )
    tools_menu.add_separator( )
    @@spawn_menu = tools_menu.add_submenu( 'Add GMech Metadata' )
    
    def self.add_spawn_item ( meta )
        @@spawn_menu.add_item( meta.friendly_name ) do
            meta.spawn( )
        end
    end
    
  #Instance Setup
  public
    attr_reader :definition, :internal_name, :friendly_name, :full_path
    
    #'param' is a hashtable used for named parameters.
    #It currently supports the following parameters:
    # :model         --> Gives a path relative to the 'plugins' folder
    # :internal_name --> Gives the internal name of the metadata
    # :friendly_name --> Gives the friendly name of the metadata
    def initialize ( param )
        relative_path = 'plugins/' + param[ :model ]
        @full_path = Sketchup.find_support_file( relative_path )
            if not @full_path then
                raise ArgumentError, ( "Couldn't find model at '%s'" % relative_path )
            end
        
        @internal_name = param[ :internal_name ]
        @friendly_name = param[ :friendly_name ]
        
        self.reload_definition( )
        
        GmkSpatialMetadataBase.register_metadata( self )
        GmkSpatialMetadataBase.add_spawn_item( self )
        
        #TODO: ...
    end
  
    def reload_definition ( model = Sketchup.active_model )
        @definition = model.definitions.load( @full_path )
            if not @definition then
                raise ArgumentError, ( "Couldn't load component from '%s'" % relative_path )
            end
        GmkSpatialMetadataBase.set_up_initialization_callback( self )
    end
    
    def spawn ( )
        model = Sketchup.active_model
        
        model.layers.add( 'GMechMetadata' ).visible = true
        model.place_component( @definition, false )
    end
    
    def on_right_click ( instance, menu )
        menu.add_separator( )
        
        dict = instance.attribute_dictionary( 'GMechMetadata', false )
        
        if self.respond_to?( :edit_metadata ) then
            self.edit_metadata( instance, dict )
        end
        
        #TEMP
        menu.add_item( "See export data..." ) do
            UI.messagebox( self.export_metadata( instance, dict ) )
        end
    end
    
    def initialize_metadata ( inst, default_dict )
        default_dict[ 'internal_name' ] = @internal_name
        default_dict[ 'friendly_name' ] = @friendly_name
        
        inst.layer = Sketchup.active_model.layers.add( 'GMechMetadata' )
        
        #UI.messagebox( "You placed a %s (%s)!" % [ @friendly_name, @internal_name ] )
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
        return exp.export( )
    end
  
  #Plugin-Initialization Stuff
    #Create "Export Metadata..." item
    tools_menu.add_item( "Export Metadata..." ) do
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
    end
    
    #Setup context-menu callbacks
    UI.add_context_menu_handler do | menu |
        curr_selection = Sketchup.active_model.selection
        
        if curr_selection.single_object? then
            entity = curr_selection.first
            dict = entity.attribute_dictionary( 'GMechMetadata', false )
            if dict then
                self.lookup_meta( dict[ 'internal_name' ] ).on_right_click( entity, menu )
            end
        end
    end
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
  public
    def onNewModel ( model )
        self.refresh_definitions( model )
    end
    
    def onOpenModel ( model )
        self.refresh_definitions( model )
    end
  
  protected
    def refresh_definitions ( model )
        GmkSpatialMetadataBase.each_metadata do | metadata |
            metadata.reload_definition( model )
        end
    end
    
    #Setup definition-reload callbacks
    Sketchup.add_observer( GmkSpatialMetadataBase_AppObserver.new( ) )
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