class LuaExportHelper
    MaxLineLength = 80
    
  public
    def initialize ( )
        @buf = [""]
        @last_type = nil
        
        return
    end
    
    def add_array_part ( value )
        if @last_type != nil then
            if @last_type != 'array' then
                self.append(";"); self.new_line()
            else
                self.append(",");
                if @buf.last.length > MaxLineLength then
                    self.new_line()
                else
                    self.append(" ")
                end
            end
        end
        
        if ( (@buf.last.length + value.length) > MaxLineLength ) and ( value.length <= MaxLineLength ) then
            self.new_line()
        end
        
        self.append( value )
        @last_type = 'array'
        
        return
    end
    
    def add_record_part ( key, value )
        if @last_type != nil then self.append(";"); self.new_line() end
        
        self.append( "%s = %s" % [ key, value ] )
        @last_type = 'record'
        
        return
    end
    
    def add_explicit_part ( key, value )
        if @last_type != nil then self.append(";"); self.new_line() end
        
        self.append( "[ %s ] = %s" % [ key, value ] )
        @last_type = 'explicit'
        
        return
    end
    
    def export ( )
        return "{" + @buf.join( "\n" ) + " }"
    end
    
  protected
    def append ( str )
        @buf.push( @buf.pop + str )
    end
    
    def new_line ( )
        @buf.push( "" )
    end
end

class String
    #TEMP
    def enquote_lua_single ( )
        return "'%s'" % self
    end
    
    #TEMP
    def enquote_lua_double ( )
        return '"%s"' % self
    end
    
    #TEMP
    def enquote_lua_long ( )
        return "[[%s]]" % self
    end
end