function __scribble_font_add_sdf_from_project(_sprite)
{
    var _name = sprite_get_name(_sprite);
    
    var _scribble_state = __scribble_get_state();
    if (_scribble_state.__default_font == undefined)
    {
        if (SCRIBBLE_VERBOSE) __scribble_trace("Setting default font to \"" + string(_name) + "\"");
        _scribble_state.__default_font = _name;
    }
    
    if (SCRIBBLE_VERBOSE) __scribble_trace("Defined \"" + _name + "\" as an SDF font");
    
    var _sprite_width  = sprite_get_width(_sprite);
    var _sprite_height = sprite_get_height(_sprite);
    var _sprite_uvs    = sprite_get_uvs(_sprite, 0);
    var _texture       = sprite_get_texture(_sprite, 0);
    
    //Correct for source sprites having their edges cropped off
    var _texel_w = texture_get_texel_width(_texture);
    var _texel_h = texture_get_texel_height(_texture);
    _sprite_uvs[0] -= _texel_w*_sprite_uvs[4];
    _sprite_uvs[1] -= _texel_h*_sprite_uvs[5];
    _sprite_uvs[2] += _texel_w*_sprite_width*(1 - _sprite_uvs[6]);
    _sprite_uvs[3] += _texel_h*_sprite_height*(1 - _sprite_uvs[7]);
    
    var _font_directory = __scribble_get_font_directory();
    var _json_buffer = buffer_load(_font_directory + _name + ".json");
    
    if (_json_buffer < 0)
    {
        _json_buffer = buffer_load(_font_directory + _name);
    }
    
    if (_json_buffer < 0)
    {
        __scribble_error("Could not find \"", _font_directory + _name + ".json\"\nPlease add it to the project's Included Files");
    }
    
    var _json_string = buffer_read(_json_buffer, buffer_text);
    buffer_delete(_json_buffer);
    var _json = json_decode(_json_string); //TODO - Replace with json_parse()
    
    var _metrics_map     = _json[? "metrics"];
    var _json_glyph_list = _json[? "glyphs" ];
    var _atlas_map       = _json[? "atlas"  ];
    var _kerning_list    = _json[? "kerning"];
    
    var _em_size     = _atlas_map[? "size"         ];
    var _sdf_pxrange = _atlas_map[? "distanceRange"];
    
    var _json_line_height = _em_size*_metrics_map[? "lineHeight"];
    
    var _size = ds_list_size(_json_glyph_list);
    if (SCRIBBLE_VERBOSE) __scribble_trace("\"" + _name + "\" has " + string(_size) + " characters");
    
    var _font_data = new __scribble_class_font(_name, _name, _size, true);
    _font_data.__runtime = true;
    
    var _font_glyphs_map      = _font_data.__glyphs_map;
    var _font_glyph_data_grid = _font_data.__glyph_data_grid;
    var _font_kerning_map     = _font_data.__kerning_map;
    
    var _is_krutidev = __scribble_asset_is_krutidev(_sprite, asset_sprite);
    if (_is_krutidev) _font_data.__is_krutidev = true;
    
    _font_data.__sdf_pxrange = _sdf_pxrange;
    
    var _i = 0;
    repeat(_size)
    {
        var _json_glyph_map = _json_glyph_list[| _i];
        var _plane_map = _json_glyph_map[? "planeBounds"];
        var _atlas_map = _json_glyph_map[? "atlasBounds"];
        
        var _unicode  = _json_glyph_map[? "unicode"];
        var _char = chr(_unicode);
        
        if (__SCRIBBLE_DEBUG) __scribble_trace("     Adding data for character \"" + string(_char) + "\" (" + string(_unicode) + ")");
        
        if (_atlas_map != undefined)
        {
            var _tex_l = _atlas_map[? "left"] + 1;
            var _tex_t = _sprite_height - _atlas_map[? "top"] + 1; //This atlas format is weird
            var _tex_r = _atlas_map[? "right"] - 1;
            var _tex_b = _sprite_height - _atlas_map[? "bottom"] - 1;
        }
        else
        {
            var _tex_l = 0;
            var _tex_t = 0;
            var _tex_r = 0;
            var _tex_b = 0;
        }
        
        var _w = _tex_r - _tex_l;
        var _h = _tex_b - _tex_t;
        
        if (_plane_map != undefined)
        {
            var _xoffset  = _em_size*_plane_map[? "left"];
            var _yoffset  = _em_size - _em_size*_plane_map[? "top"]; //So, so weird
            var _xadvance = round(_em_size*_json_glyph_map[? "advance"]); //_w - _sdf_pxrange - round(_em_size*_plane_map[? "left"]);
        }
        else
        {
            var _xoffset  = 0;
            var _yoffset  = 0;
            var _xadvance = round(_em_size*_json_glyph_map[? "advance"]);
        }
        
        if (SCRIBBLE_SDF_BORDER_TRIM > 0)
        {
            _tex_l += SCRIBBLE_SDF_BORDER_TRIM;
            _tex_t += SCRIBBLE_SDF_BORDER_TRIM;
            _tex_r -= SCRIBBLE_SDF_BORDER_TRIM;
            _tex_b -= SCRIBBLE_SDF_BORDER_TRIM;
            
            _w -= 2*SCRIBBLE_SDF_BORDER_TRIM;
            _h -= 2*SCRIBBLE_SDF_BORDER_TRIM;
            
            _xoffset += SCRIBBLE_SDF_BORDER_TRIM;
            _yoffset += SCRIBBLE_SDF_BORDER_TRIM;
        }
        
        //if (_xoffset < 0) __scribble_trace("char = ", _char, ", offset = ", _xoffset);
        
        if (__SCRIBBLE_DEBUG)
        {
            __scribble_trace(_char, "    ", _w, " x ", _h, ", advance=", _xadvance, ", dy=", _yoffset, ", diff=", _w - _xadvance);
            if (_plane_map != undefined)
            {
                __scribble_trace(_char, "    ", round(_em_size*(_plane_map[? "right"] - _plane_map[? "left"])));
                __scribble_trace(_char, "    ", _xadvance);
            }
        }
        
        var _u0 = lerp(_sprite_uvs[0], _sprite_uvs[2], _tex_l/_sprite_width );
        var _v0 = lerp(_sprite_uvs[1], _sprite_uvs[3], _tex_t/_sprite_height);
        var _u1 = lerp(_sprite_uvs[0], _sprite_uvs[2], _tex_r/_sprite_width );
        var _v1 = lerp(_sprite_uvs[1], _sprite_uvs[3], _tex_b/_sprite_height);
        
        var _bidi = __scribble_unicode_get_bidi(_unicode);
        
        if (_is_krutidev)
        {
            __SCRIBBLE_KRUTIDEV_HACK
        }
        
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__CHARACTER           ] = _char;
        
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__UNICODE             ] = _unicode;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__BIDI                ] = _bidi;
                                                                        
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__X_OFFSET            ] = _xoffset;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__Y_OFFSET            ] = _yoffset;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__WIDTH               ] = _w;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__HEIGHT              ] = _h;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__FONT_HEIGHT         ] = _json_line_height;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__SEPARATION          ] = _xadvance;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__LEFT_OFFSET         ] = 1 - _xoffset - 0.5*_sdf_pxrange;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__FONT_SCALE          ] = 1;
        
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__TEXTURE             ] = _texture;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__U0                  ] = _u0;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__V0                  ] = _v0;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__U1                  ] = _u1;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__V1                  ] = _v1;
        
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__SDF_PXRANGE         ] = _sdf_pxrange;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__SDF_THICKNESS_OFFSET] = 0;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__BILINEAR            ] = true;
        
        _font_glyphs_map[? _unicode] = _i;
        
        ++_i;
    }
    
    //Guarantee we have a space character
    var _space_index = _font_glyphs_map[? 32];
    if (_space_index == undefined)
    {
        __scribble_trace("Warning! Space character not found in character set for SDF font \"", _name, "\"");
        
        var _i = _size;
        ds_grid_resize(_font_glyph_data_grid, _i+1, __SCRIBBLE_GLYPH.__SIZE);
        _font_glyphs_map[? 32] = _i;
        
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__CHARACTER           ] = " ";
        
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__UNICODE             ] = 0x20;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__BIDI                ] = __SCRIBBLE_BIDI.WHITESPACE;
        
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__X_OFFSET            ] = 0;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__Y_OFFSET            ] = 0;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__WIDTH               ] = 0.5*_json_line_height;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__HEIGHT              ] = _json_line_height;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__FONT_HEIGHT         ] = _json_line_height;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__SEPARATION          ] = 0.5*_json_line_height;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__LEFT_OFFSET         ] = 0;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__FONT_SCALE          ] = 1;
        
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__TEXTURE             ] = _texture;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__U0                  ] = 0;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__V0                  ] = 0;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__U1                  ] = 0;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__V1                  ] = 0;
        
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__SDF_PXRANGE         ] = _sdf_pxrange;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__SDF_THICKNESS_OFFSET] = 0;
        _font_glyph_data_grid[# _i, __SCRIBBLE_GLYPH.__BILINEAR            ] = true;
    }
    
    //And guarantee the space character is set up
    var _space_index = _font_glyphs_map[? 32];
    _font_glyph_data_grid[# _space_index, __SCRIBBLE_GLYPH.__WIDTH ] = _font_glyph_data_grid[# _space_index, __SCRIBBLE_GLYPH.__SEPARATION];
    _font_glyph_data_grid[# _space_index, __SCRIBBLE_GLYPH.__HEIGHT] = _json_line_height;
    
    if (SCRIBBLE_USE_KERNING)
    {
        var _i = 0;
        repeat(ds_list_size(_kerning_list))
        {
            var _kerning_pair = _kerning_list[| _i];
            var _offset = round(_em_size*_kerning_pair[? "advance"]);
            if (_offset != 0) _font_kerning_map[? ((_kerning_pair[? "unicode2"] & 0xFFFF) << 16) | (_kerning_pair[? "unicode1"] & 0xFFFF)] = _offset;
            ++_i;
        }
    }
    
    ds_map_destroy(_json);
    
    _font_data.__calculate_font_height();
}