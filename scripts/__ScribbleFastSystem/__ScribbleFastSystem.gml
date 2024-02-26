// Feather disable all

function __ScribbleFastSystem()
{
    static _system = undefined;
    if (is_struct(_system)) return _system;
    
    _system = {};
    with(_system)
    {
        __cache         = {};
        __cacheTest     = {};
        __cacheFontInfo = {};
        
        __budget     = 1000;
        __budgetUsed = 0;
        
        __defaultFont = fntTest;
        
        __colourDict = {};
        __colourDict[$ "c_red"  ] = c_red;
        __colourDict[$ "c_blue" ] = c_blue;
        __colourDict[$ "c_lime" ] = c_lime;
        __colourDict[$ "/c"     ] = -1;
        __colourDict[$ "/color" ] = -1;
        __colourDict[$ "/colour"] = -1;
        
        vertex_format_begin();
        vertex_format_add_custom(vertex_type_float2, vertex_usage_position);
        vertex_format_add_texcoord();
        __vertexFormatA = vertex_format_end();
        
        vertex_format_begin();
        vertex_format_add_custom(vertex_type_float2, vertex_usage_position);
        vertex_format_add_color();
        vertex_format_add_texcoord();
        __vertexFormatB = vertex_format_end();
    }
    
    time_source_start(time_source_create(time_source_global, 1, time_source_units_frames, function()
    {
        static _system = __ScribbleFastSystem();
        _system.__budgetUsed = 0;
    },
    [], -1));
    
    return _system;
}