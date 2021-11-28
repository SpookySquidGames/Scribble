function __scribble_gen_10_write_vbuffs()
{
    if (SCRIBBLE_ALLOW_PAGE_TEXT_GETTER)
    {
        var _string_buffer = global.__scribble_buffer;
    }
    
    var _glyph_grid    = global.__scribble_glyph_grid;
    var _control_grid  = global.__scribble_control_grid; //This grid is cleared at the bottom of __scribble_generate_model()
    
    var _element     = global.__scribble_generator_state.element;
    var _glyph_count = global.__scribble_generator_state.glyph_count;
    
    if (is_array(global.__scribble_generator_state.bezier_lengths_array))
    {
        //Prep for Bezier curve shenanigans if necessary
        var _bezier_do              = true;
        var _bezier_lengths         = global.__scribble_generator_state.bezier_lengths_array;
        var _bezier_search_index    = 0;
        var _bezier_search_d0       = 0;
        var _bezier_search_d1       = _bezier_lengths[1];
        var _bezier_prev_cy         = -infinity;
        var _bezier_param_increment = 1 / (SCRIBBLE_BEZIER_ACCURACY-1);
    }
    else
    {
        _bezier_do = false;
    }
    
    var _vbuff_pos_grid = global.__scribble_vbuff_pos_grid;
    
    var _glyph_scale        = 1.0;
    var _glyph_colour       = 0xFFFFFFFF;
    var _glyph_cycle        = 0x00000000;
    var _glyph_effect_flags = 0;
    var _glyph_sprite_data  = 0;
    var _write_colour       = 0xFFFFFFFF;
    
    var _control_index = 0;
    
    var _p = 0;
    repeat(pages)
    {
        var _page_data          = pages_array[_p];
        var _page_events_dict   = _page_data.__events;
        var _vbuff              = undefined;
        var _last_glyph_texture = undefined;
        
        if (SCRIBBLE_ALLOW_PAGE_TEXT_GETTER)
        {
            buffer_seek(_string_buffer, buffer_seek_start, 0);
        }
        
        var _i = _page_data.__glyph_start;
        repeat(1 + _page_data.__glyph_end - _page_data.__glyph_start)
        {
            #region Read controls
            
            var _control_delta = _glyph_grid[# _i, __SCRIBBLE_PARSER_GLYPH.CONTROL_COUNT] - _control_index;
            repeat(_control_delta)
            {
                switch(_control_grid[# _control_index, __SCRIBBLE_PARSER_CONTROL.TYPE])
                {
                    case __SCRIBBLE_CONTROL_TYPE.COLOUR:
                        _glyph_colour = _control_grid[# _control_index, __SCRIBBLE_PARSER_CONTROL.DATA];
                        var _write_colour = (__SCRIBBLE_ON_OPENGL? scribble_rgb_to_bgr(_glyph_colour) : _glyph_colour); //Fix for bug in vertex_argb() on OpenGL targets (2021-11-24  runtime 2.3.5.458)
                    break;
                    
                    case __SCRIBBLE_CONTROL_TYPE.EFFECT:
                        _glyph_effect_flags = _control_grid[# _control_index, __SCRIBBLE_PARSER_CONTROL.DATA];
                    break;
                    
                    case __SCRIBBLE_CONTROL_TYPE.CYCLE:
                        _glyph_cycle = _control_grid[# _control_index, __SCRIBBLE_PARSER_CONTROL.DATA];
                        
                        if (_glyph_cycle == undefined)
                        {
                            _glyph_effect_flags = ~((~_glyph_effect_flags) | (1 << global.__scribble_effects[? "cycle"]));
                            _write_colour = (__SCRIBBLE_ON_OPENGL? scribble_rgb_to_bgr(_glyph_colour) : _glyph_colour); //Fix for bug in vertex_argb() on OpenGL targets (2021-11-24  runtime 2.3.5.458)
                        }
                        else
                        {
                            _glyph_effect_flags |= (1 << global.__scribble_effects[? "cycle"]);
                            _write_colour = (__SCRIBBLE_ON_OPENGL? scribble_rgb_to_bgr(_glyph_cycle) : _glyph_cycle); //Fix for bug in vertex_argb() on OpenGL targets (2021-11-24  runtime 2.3.5.458)
                        }
                    break;
                    
                    case __SCRIBBLE_CONTROL_TYPE.EVENT:
                        var _animation_index = _i; //TODO
                        var _event_array = _page_events_dict[$ _animation_index]; //Find the correct event array in the diciontary, creating a new one if needed
                        
                        if (!is_array(_event_array))
                        {
                            var _event_array = [];
                            _page_events_dict[$ _animation_index] = _event_array;
                        }
                        
                        var _event = _control_grid[# _control_index, __SCRIBBLE_PARSER_CONTROL.DATA];
                        _event.position = _animation_index; //Update the glyph index to the *local* glyph index for the page
                        array_push(_event_array, _event);
                    break;
                }
                
                _control_index++;
            }
            
            #endregion
            
            var _glyph_ord = _glyph_grid[# _i, __SCRIBBLE_PARSER_GLYPH.ORD];
            if (_glyph_ord == __SCRIBBLE_GLYPH_SPRITE)
            {
                #region Write sprite
                
                if (SCRIBBLE_ALLOW_PAGE_TEXT_GETTER)
                {
                    buffer_write(_string_buffer, buffer_u8, 0x1A); //Unicode/ASCII "substitute character"
                }
                
                var _glyph_x        = _glyph_grid[# _i, __SCRIBBLE_PARSER_GLYPH.X              ];
                var _glyph_y        = _glyph_grid[# _i, __SCRIBBLE_PARSER_GLYPH.Y              ];
                var _glyph_width    = _glyph_grid[# _i, __SCRIBBLE_PARSER_GLYPH.WIDTH          ];
                var _glyph_height   = _glyph_grid[# _i, __SCRIBBLE_PARSER_GLYPH.HEIGHT         ];
                
                var _packed_indexes = _glyph_grid[# _i, __SCRIBBLE_PARSER_GLYPH.ANIMATION_INDEX];
                
                var _sprite_index   = _glyph_grid[# _i, __SCRIBBLE_PARSER_GLYPH.SPRITE_INDEX   ];
                var _image_index    = _glyph_grid[# _i, __SCRIBBLE_PARSER_GLYPH.IMAGE_INDEX    ];
                var _image_speed    = _glyph_grid[# _i, __SCRIBBLE_PARSER_GLYPH.IMAGE_SPEED    ];
                
                var _glyph_xscale = sprite_get_width(_sprite_index) / _glyph_width;
                var _glyph_yscale = sprite_get_height(_sprite_index) / _glyph_height;
                
                var _old_glyph_effect_flags = _glyph_effect_flags;
                
                if (!SCRIBBLE_COLORIZE_SPRITES)
                {
                    var _old_write_colour = _write_colour;
                    _write_colour = _glyph_colour | 0xFFFFFF; //Make sure we use the general glyph alpha
                    
                    _glyph_effect_flags = ~_glyph_effect_flags;
                    _glyph_effect_flags |= (1 << global.__scribble_effects[? "rainbow"]);
                    _glyph_effect_flags |= (1 << global.__scribble_effects[? "cycle"  ]);
                    _glyph_effect_flags = ~_glyph_effect_flags;
                }
                
                if (_image_speed > 0) _glyph_effect_flags |= 1; //Set the sprite flag bit
                
                if (SCRIBBLE_ADD_SPRITE_ORIGINS)
                {
                    _glyph_x += (_glyph_width  div 2) - _glyph_xscale*sprite_get_xoffset(_sprite_index);
                    _glyph_y += (_glyph_height div 2) - _glyph_yscale*sprite_get_yoffset(_sprite_index);
                }
                
                var _sprite_number = sprite_get_number(_sprite_index);
                if (_sprite_number >= 64)
                {
                    __scribble_trace("In-line sprites cannot have more than 64 frames (", sprite_get_name(_sprite_index), ")");
                    _sprite_number = 64;
                }
                
                if (_image_speed >= 4)
                {
                    __scribble_trace("Image speed cannot be more than 4.0 (" + string(_image_speed) + ")");
                    _image_speed = 4;
                }
                
                if (_image_speed < 0)
                {
                    __scribble_trace("Image speed cannot be less than 0.0 (" + string(_image_speed) + ")");
                    _image_speed = 0;
                }
                
                var _glyph_sprite_data = 4096*floor(1024*_image_speed) + 64*_sprite_number + _image_index;
                
                var _j = _image_index;
                repeat((_image_speed > 0)? _sprite_number : 1) //Only draw one image if we have an image speed of 0 since we're not animating
                {
                    var _glyph_texture = sprite_get_texture(_sprite_index, _j);
                    
                    var _uvs = sprite_get_uvs(_sprite_index, _j);
                    var _quad_u0 = _uvs[0];
                    var _quad_v0 = _uvs[1];
                    var _quad_u1 = _uvs[2];
                    var _quad_v1 = _uvs[3];
                    
                    var _quad_l = floor(_glyph_x + _uvs[4]*_glyph_xscale);
                    var _quad_t = floor(_glyph_y + _uvs[5]*_glyph_yscale);
                    var _quad_r = _quad_l  + _uvs[6]*_glyph_width;
                    var _quad_b = _quad_t  + _uvs[7]*_glyph_height;
                    
                    var _half_w = 0.5*(_quad_r - _quad_l);
                    var _half_h = 0.5*(_quad_b - _quad_t);
                    
                    __SCRIBBLE_VBUFF_WRITE_GLYPH;
                    
                    ++_j;
                    ++_glyph_sprite_data;
                }
                
                if (!SCRIBBLE_COLORIZE_SPRITES) _write_colour = _old_write_colour;
                _glyph_effect_flags = _old_glyph_effect_flags;
                _glyph_sprite_data = 0; //Reset this because every other type of glyph doesn't use this
                
                #endregion
            }
            else if (_glyph_ord == __SCRIBBLE_GLYPH_SURFACE)
            {
                if (SCRIBBLE_ALLOW_PAGE_TEXT_GETTER)
                {
                    buffer_write(_string_buffer, buffer_u8, 0x1A); //Unicode/ASCII "substitute character"
                }
                
                __SCRIBBLE_VBUFF_READ_GLYPH;
                
                if (!SCRIBBLE_COLORIZE_SPRITES)
                {
                    var _old_write_colour       = _write_colour;
                    var _old_glyph_effect_flags = _glyph_effect_flags;
                    
                    _write_colour = _write_colour | 0xFFFFFF;
                    
                    _glyph_effect_flags = ~_glyph_effect_flags;
                    _glyph_effect_flags |= (1 << global.__scribble_effects[? "rainbow"]);
                    _glyph_effect_flags |= (1 << global.__scribble_effects[? "cycle"  ]);
                    _glyph_effect_flags = ~_glyph_effect_flags;
                }
                
                __SCRIBBLE_VBUFF_WRITE_GLYPH;
                
                if (!SCRIBBLE_COLORIZE_SPRITES)
                {
                    _write_colour       = _old_write_colour;
                    _glyph_effect_flags = _old_glyph_effect_flags;
                }
            }
            else
            {
                if (SCRIBBLE_ALLOW_PAGE_TEXT_GETTER)
                {
                    __scribble_buffer_write_unicode(_string_buffer, _glyph_ord);
                }
                
                if ((_glyph_ord > 32) && (_glyph_ord != 0x200B))
                {
                    if (SCRIBBLE_ALLOW_PAGE_TEXT_GETTER)
                    {
                        __scribble_buffer_write_unicode(_string_buffer, _glyph_ord);
                    }
                    
                    __SCRIBBLE_VBUFF_READ_GLYPH;
                    __SCRIBBLE_VBUFF_WRITE_GLYPH;
                }
            }
            
            ++_i;
        }
        
        if (SCRIBBLE_ALLOW_PAGE_TEXT_GETTER)
        {
            //Write a null terminator to finish off the string
            buffer_write(_string_buffer, buffer_u8, 0);
            buffer_seek(_string_buffer, buffer_seek_start, 0);
            _page_data.__text = buffer_read(_string_buffer, buffer_string);
        }
        
        characters += _page_data.__character_count;
        
        ++_p;
    }
    
    //Sweep up any remaining controls
    var _control_delta = _glyph_grid[# _i, __SCRIBBLE_PARSER_GLYPH.CONTROL_COUNT] - _control_index;
    repeat(_control_delta)
    {
        if (_control_grid[# _control_index, __SCRIBBLE_PARSER_CONTROL.TYPE] == __SCRIBBLE_CONTROL_TYPE.EVENT)
        {
            var _animation_index = _i; //TODO
            var _event_array = _page_events_dict[$ _animation_index]; //Find the correct event array in the diciontary, creating a new one if needed
            
            if (!is_array(_event_array))
            {
                var _event_array = [];
                _page_events_dict[$ _animation_index] = _event_array;
            }
            
            var _event = _control_grid[# _control_index, __SCRIBBLE_PARSER_CONTROL.DATA];
            _event.position = _animation_index; //Update the glyph index to the *local* glyph index for the page
            array_push(_event_array, _event);
        }
                
        _control_index++;
    }
    
    //Ensure we've ended the vertex buffers we created
    __finalize_vertex_buffers(_element.freeze);
}