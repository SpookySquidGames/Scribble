#macro __SCRIBBLE_PAGE_VALIDATE_LINE_INDEX  if (_line_index < 0) __scribble_error("Line index ", _line_index, " doesn't exist. Minimum line index is 0");\
                                            var _line_count = array_length(__line_array);\
                                            if (_line_index >= _line_count) __scribble_error("Line index ", _line_index, " doesn't exist. Maximum line index is ", _line_count-1);

function __scribble_class_page() constructor
{
    static __scribble_state = __scribble_get_state();
    static __gc_vbuff_refs  = __scribble_get_cache_state().__gc_vbuff_refs;
    static __gc_vbuff_ids   = __scribble_get_cache_state().__gc_vbuff_ids;
    
    __text = "";
    __glyph_grid = undefined;
    
    __created_frame = __scribble_state.__frames;
    __frozen = undefined;
    
    __character_count = 0;
    
    __glyph_start = undefined;
    __glyph_end   = undefined;
    __glyph_count = 0;
    
    __line_start = undefined;
    __line_end   = undefined;
    __line_count = 0;
    
    __line_array = [];
    
    __width  = 0;
    __height = 0;
    __min_x  = 0;
    __min_y  = 0;
    __max_x  = 0;
    __max_y  = 0;
    
    __vertex_buffer_array = [];
    if (!__SCRIBBLE_ON_WEB) __texture_to_vertex_buffer_dict = {}; //FIXME - Workaround for pointers not being stringified properly on HTML5
    
    __char_events  = {};
    __line_events  = {};
    __region_array = [];
    
    static __submit = function(_double_draw)
    {
        static _u_fRenderFlags        = shader_get_uniform(__shd_scribble, "u_fRenderFlags"       );
        static _u_vTexel              = shader_get_uniform(__shd_scribble, "u_vTexel"             );
        static _u_fSDFRange           = shader_get_uniform(__shd_scribble, "u_fSDFRange"          );
        static _u_fSDFThicknessOffset = shader_get_uniform(__shd_scribble, "u_fSDFThicknessOffset");
        
        if (SCRIBBLE_INCREMENTAL_FREEZE && !__frozen && (__created_frame < __scribble_state.__frames)) __freeze();
        
        var _render_flag_value = __scribble_state.__render_flag_value;
        
        var _i = 0;
        repeat(array_length(__vertex_buffer_array))
        {
            var _data = __vertex_buffer_array[_i];
            var _bilinear      = _data[__SCRIBBLE_VERTEX_BUFFER.__BILINEAR     ];
            var _sdf           = _data[__SCRIBBLE_VERTEX_BUFFER.__SDF          ];
            var _baked_effects = _data[__SCRIBBLE_VERTEX_BUFFER.__BAKED_EFFECTS];
            
            if (_bilinear != undefined)
            {
                var _old_tex_filter = gpu_get_tex_filter();
                gpu_set_tex_filter(_bilinear);
            }
            
            //Reset all render flags (baked effects, SDF, and double draw)
            _render_flag_value = (_render_flag_value & (~(0x1C)));
            
            if (_sdf)
            {
                //Set the "SDF" render flag
                _render_flag_value |= 0x08;
                
                //Set shader uniforms unique to the SDF shader
                shader_set_uniform_f(_u_vTexel, _data[__SCRIBBLE_VERTEX_BUFFER.__TEXEL_WIDTH], _data[__SCRIBBLE_VERTEX_BUFFER.__TEXEL_HEIGHT]);
                shader_set_uniform_f(_u_fSDFRange, (_data[__SCRIBBLE_VERTEX_BUFFER.__SDF_RANGE] ?? 0));
                shader_set_uniform_f(_u_fSDFThicknessOffset, __scribble_state.__sdf_thickness_offset + (_data[__SCRIBBLE_VERTEX_BUFFER.__SDF_THICKNESS_OFFSET] ?? 0));
            }
            else
            {
                //Set the "baked effects" render flag
                _render_flag_value |= (_baked_effects << 2);
            }
            
            shader_set_uniform_f(_u_fRenderFlags, _render_flag_value);
            vertex_submit(_data[__SCRIBBLE_VERTEX_BUFFER.__VERTEX_BUFFER], pr_trianglelist, _data[__SCRIBBLE_VERTEX_BUFFER.__TEXTURE]);
            
            if (_double_draw && (_sdf || _baked_effects))
            {
                //Set the "double draw" render flag
                shader_set_uniform_f(_u_fRenderFlags, _render_flag_value | 0x10);
                vertex_submit(_data[__SCRIBBLE_VERTEX_BUFFER.__VERTEX_BUFFER], pr_trianglelist, _data[__SCRIBBLE_VERTEX_BUFFER.__TEXTURE]);
            }
            
            if (_bilinear != undefined)
            {
                //Reset the texture filtering
                gpu_set_tex_filter(_old_tex_filter);
            }
            
            ++_i;
        }
    }
    
    static __freeze = function()
    {
        if (!__frozen)
        {
            if (SCRIBBLE_VERBOSE)
            {
                var _t = get_timer();
            }
            
            var _i = 0;
            repeat(array_length(__vertex_buffer_array))
            {
                vertex_freeze(__vertex_buffer_array[_i][__SCRIBBLE_VERTEX_BUFFER.__VERTEX_BUFFER]);
                ++_i;
            }
            
            __frozen = true;
            
            if (SCRIBBLE_VERBOSE)
            {
                __scribble_trace("Incrementally froze page vertex buffers, time taken = ", (get_timer() - _t)/1000, "ms");
            }
        }
    }
    
    /// @param glyphIndex
    static __get_glyph_data = function(_index)
    {
        if (!SCRIBBLE_ALLOW_GLYPH_DATA_GETTER) __scribble_error("Cannot get glyph data, SCRIBBLE_ALLOW_GLYPH_DATA_GETTER = <false>\nPlease set SCRIBBLE_ALLOW_GLYPH_DATA_GETTER to <true> to get glyph data");
        
        if (_index < 0)
        {
            return {
                unicode: 0,
                left:    __glyph_grid[# 0, __SCRIBBLE_GLYPH_LAYOUT.__LEFT  ],
                top:     __glyph_grid[# 0, __SCRIBBLE_GLYPH_LAYOUT.__TOP   ],
                right:   __glyph_grid[# 0, __SCRIBBLE_GLYPH_LAYOUT.__LEFT  ],
                bottom:  __glyph_grid[# 0, __SCRIBBLE_GLYPH_LAYOUT.__BOTTOM],
            };
        }
        else
        {
            _index = min(_index, __glyph_count-1);
            
            return {
                unicode: __glyph_grid[# _index, __SCRIBBLE_GLYPH_LAYOUT.__UNICODE],
                left:    __glyph_grid[# _index, __SCRIBBLE_GLYPH_LAYOUT.__LEFT   ],
                top:     __glyph_grid[# _index, __SCRIBBLE_GLYPH_LAYOUT.__TOP    ],
                right:   __glyph_grid[# _index, __SCRIBBLE_GLYPH_LAYOUT.__RIGHT  ],
                bottom:  __glyph_grid[# _index, __SCRIBBLE_GLYPH_LAYOUT.__BOTTOM ],
            };
        }
    }
    
    /// @param lineIndex
    static __get_line_y = function(_line_index)
    {
        __SCRIBBLE_PAGE_VALIDATE_LINE_INDEX
        return __line_array[_line_index].__y;
    }
    
    /// @param lineIndex
    static __get_line_height = function(_line_index)
    {
        __SCRIBBLE_PAGE_VALIDATE_LINE_INDEX
        return __line_array[_line_index].__height;
    }
    
    static __get_scroll_max = function()
    {
        var _line_count = array_length(__line_array);
        if (_line_count <= 0) return 0;
        
        with(__line_array[_line_count-1])
        {
            return __y + __height;
        }
    }
    
    static __get_vertex_buffer = function(_texture, _pxrange, _thickness_offset, _bilinear, _baked_effects, _model_struct)
    {
        var _pointer_string = string(_texture);
        
        if (!__SCRIBBLE_ON_WEB)
        {
            var _data = __texture_to_vertex_buffer_dict[$ _pointer_string];
        }
        else //FIXME - Workaround for pointers not being stringified properly on HTML5
        {
            var _data = undefined;
            var _i = 0;
            repeat(array_length(__vertex_buffer_array))
            {
                var _vbuff_data = __vertex_buffer_array[_i];
                if (_vbuff_data[__SCRIBBLE_VERTEX_BUFFER.__TEXTURE] == _texture)
                {
                    _data = _vbuff_data;
                    break;
                }
                
                ++_i;
            }
        }
        
        if (_data == undefined)
        {
            static _vertex_format = undefined;
            if (_vertex_format == undefined)
            {
                vertex_format_begin();
                vertex_format_add_position_3d();                                  //12 bytes
                vertex_format_add_normal();                                       //12 bytes
                vertex_format_add_colour();                                       // 4 bytes
                vertex_format_add_texcoord();                                     // 8 bytes
                vertex_format_add_custom(vertex_type_float3, vertex_usage_color); //12 bytes
                _vertex_format = vertex_format_end();                             //48 bytes per vertex, 144 bytes per tri, 288 bytes per glyph
            }
            
            var _vbuff = vertex_create_buffer(); //TODO - Can we preallocate this? i.e. copy "for text" system we had in the old version
            vertex_begin(_vbuff, _vertex_format);
            
            if (__SCRIBBLE_VERBOSE_GC) __scribble_trace("Adding vertex buffer ", _vbuff, " to tracking");
            array_push(__gc_vbuff_refs, weak_ref_create(self));
            array_push(__gc_vbuff_ids, _vbuff);
            
            var _data = array_create(__SCRIBBLE_VERTEX_BUFFER.__SIZE);
            _data[@ __SCRIBBLE_VERTEX_BUFFER.__VERTEX_BUFFER       ] = _vbuff;
            _data[@ __SCRIBBLE_VERTEX_BUFFER.__TEXTURE             ] = _texture;
            _data[@ __SCRIBBLE_VERTEX_BUFFER.__SDF                 ] = (_pxrange != undefined); //We're using an SDF font if we have no defined SDF range
            _data[@ __SCRIBBLE_VERTEX_BUFFER.__SDF_RANGE           ] = _pxrange;
            _data[@ __SCRIBBLE_VERTEX_BUFFER.__SDF_THICKNESS_OFFSET] = _thickness_offset;
            _data[@ __SCRIBBLE_VERTEX_BUFFER.__TEXEL_WIDTH         ] = texture_get_texel_width(_texture);
            _data[@ __SCRIBBLE_VERTEX_BUFFER.__TEXEL_HEIGHT        ] = texture_get_texel_height(_texture);
            _data[@ __SCRIBBLE_VERTEX_BUFFER.__BILINEAR            ] = _bilinear;
            _data[@ __SCRIBBLE_VERTEX_BUFFER.__BAKED_EFFECTS       ] = _baked_effects;
            
            __vertex_buffer_array[@ array_length(__vertex_buffer_array)] = _data;
            if (!__SCRIBBLE_ON_WEB) __texture_to_vertex_buffer_dict[$ _pointer_string] = _data;
            
            return _vbuff;
        }
        else
        {
            return _data[__SCRIBBLE_VERTEX_BUFFER.__VERTEX_BUFFER];
        }
    }
    
    static __finalize_vertex_buffers = function(_freeze)
    {
        var _i = 0;
        repeat(array_length(__vertex_buffer_array))
        {
            var _vbuff = __vertex_buffer_array[_i][__SCRIBBLE_VERTEX_BUFFER.__VERTEX_BUFFER];
            vertex_end(_vbuff);
            if (_freeze) vertex_freeze(_vbuff);
            
            ++_i;
        }
        
        __frozen = _freeze;
    }
    
    static __flush = function()
    {
        var _i = 0;
        repeat(array_length(__vertex_buffer_array))
        {
            var _vbuff = __vertex_buffer_array[_i][__SCRIBBLE_VERTEX_BUFFER.__VERTEX_BUFFER];
            vertex_delete_buffer(_vbuff);
            
            var _index = __scribble_array_find_index(__gc_vbuff_ids, _vbuff);
            if (_index >= 0)
            {
                if (__SCRIBBLE_VERBOSE_GC) __scribble_trace("Manually removing vertex buffer ", _vbuff, " from tracking");
                array_delete(__gc_vbuff_refs, _index, 1);
                array_delete(__gc_vbuff_ids,  _index, 1);
            }
            
            ++_i;
        }
        
        __texture_to_vertex_buffer_dict = {};
        array_resize(__vertex_buffer_array, 0);
    }
}