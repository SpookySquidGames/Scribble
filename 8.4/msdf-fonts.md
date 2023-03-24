# MSDF Fonts

?> This guide was written for version 1.1 of the [MSDF atlas generator](https://github.com/Chlumsky/msdf-atlas-gen), released 18th October 2020.

## Introduction

MSDF fonts allow for text to be rendered at any size without needing to generate a unique font for each size. This effectively means MSDF fonts are resolution-independent, making them useful for software UIs in general, but essential for mobile game development. MSDFs reduce the texture memory usage of your game whilst also being easier to use and maintain. With Scribble, MSDF fonts are rendered at the same speed as normal fonts. MSDF fonts are supported for all of Scribble's target platforms.

MSDF stands for "Multi-channel Signed Distance Field". It is a relatively new technique invented by Viktor Chlumsky in 2015 designed to address the limitations of the famous SDF method proposed by Valve in their 2007 SIGGRAPH paper. MSDFs typically produce superior results to SDFs owing to their better representation of sharp edges, and their more efficient use of RGB colourspace to allow for greater information about the shape to be stored.

This guide won't explain how MSDFs work at the implementation level; I recommend reading Chlumsky's own words if you'd like to understand the method in detail. This guide will explain how to generate MSDF font atlases and will lay out best practice when using MSDF fonts with Scribble.

At this time, this guide will only explain how to generate MSDF fonts on Windows. It is entirely possible to generate fonts on MacOS as well, but I don't have access to hardware to test the process out myself. If you'd like to collaberate on writing a MacOS-specific guide, please get in touch.

## Generating an MSDF Atlas

Download the Windows binaries [here](https://github.com/Chlumsky/msdf-atlas-gen/releases/tag/v1.1) (you'll probably want the 64-bit binaries) and extract the .zip file to a directory - it only contains a single executable, `msdf-atlas-gen.exe`. This is a command line tool; we'll be controlling it with a batch file.

In addition to `msdf-atlas-gen.exe`, we'll need two other source files in the directory:

1. TrueType Font (.ttf) file for your font

2. UTF-8 encoded text file that contains all the characters that you want to use with the font. This is similar to the "mapstring" for [`font_add_sprite_ext`](https://manual.yoyogames.com/GameMaker_Language/GML_Reference/Asset_Management/Fonts/font_add_sprite.htm). 

!> Remember to include a space character in your `charset.txt`!

Let's assume our font file is called `font.ttf` and our character textfile is called `charset.txt`. This means your directory should contain `msdf-atlas-gen.exe`, `font.ttf`, and `charset.txt`.

&nbsp;

Next, we need to create a batch file to get the tool to do what we want. There are a few ways to do this, but the easiest is usually to create a text file and then change the file extension to `.bat`.

Here's an example of a batch file command:

`msdf-atlas-gen.exe -font font.ttf -size 12 -charset charset.txt -format png -imageout font.png -json font.json -pxrange 4`

And here's what the parameters mean:

`-font font.ttf`<br>What font we're going to target, in this case "font.ttf"

`-size 12`<br>Size of the glyphs in the atlas in pixels per EM

`-charset charset.txt`<br>Where the tool should look for a string of characters to render i.e. "charset.txt"

`-format png`<br>Image format for the texture atlas (PNG)

`-imageout font.png`<br>Name of the image file to output

`-json font.json`<br>Name of the glyph data file to ouput, as a JSON

`-pxrange 4`<br>Range of the SDF function. Leave this at 4 unless you need to tweak the generator's output

?> Full tool documentation can be found [here](https://github.com/Chlumsky/msdf-atlas-gen/)

Once you've made your batch file, run it! You should see a .png and .json file appear in the directory indicating that the generator completed successfully. If you run into trouble, put a `pause` command on a new line in the batch file to check what the tool is outputting.

## Using an MSDF Font with Scribble

Once you've run the atlas generator using the batch file, you'll receive a .png file (the atlas) and a .json file (the glyph data). Scribble needs both to draw MSDF fonts, and Scribble also needs a line of code to tie the two resources together.

1. Import the .png image as a standard GameMaker resource. We'll call this sprite `spr_msdf_font`.

2. Add a [tag](https://manual.yoyogames.com/Introduction/The_Asset_Browser.htm) to sprite asset with the name `scribble msdf`.

3. Add the .json file as an Included File. Make sure that the name of the .json file matches the sprite asset's name. We'll call this file `spr_msdf_font.json` accordingly.

Once you've done that, now you can use the MSDF font in exactly the same way that you'd use a spritefont e.g.

`scribble("[spr_msdf_font]This is [scale,1.5]an MSDF [scale,2]font!").draw(x, y);`

If everything has gone accordingly to plan, you'll see a clean and crisp line of text!

## Best Practice for MSDF Fonts

MSDF fonts are more capable than standard fonts, but accordingly they are rather more complex to set up. The above example will get you started, but you may run into some issues as you're using MSDF fonts. Here are some things to look out for:

1. **Use the smallest `-size` value you can get away with, and only generate the glyphs that you need**

Glyphs take up space on an atlas, and having too many glyphs or glyphs that are too large will cause the atlas size to become very large. Not only will this end up using loads of texture memory, but it may also cause visual artefacts if GameMaker tries to scale down the atlas texture

2. **Avoid scaling down**

MSDF, as a technique, is designed to be scaled up. Use a small `-size` parameter when generating the atlas, then use the in-line `[scale]` tag or `.transform()` method to increase the size of your text. You can get away with scaling down, but it can lead to issues due to the way texture interpolation works on GPUs

3. **When things look weird, try increasing the `-pxrange` and/or `-size` parameters**

The `-pxrange` parameter represents the maximum distance that can be encoded by the MSDF output. A small value will lead to a more locally accurate output, but for complicated shapes (such as CJK glyphs) this might lead to glitchy output. A large `-size` parameter will allow for more space for details to be expressed by the MSDF generator

## References

[MSDF font atlas generator](https://github.com/Chlumsky/msdf-atlas-gen)

[Original MSDF thesis paper](https://github.com/Chlumsky/msdfgen/files/3050967/thesis.pdf)

[Valve's 2007 SIGGRAPH paper (SDF)](https://steamcdn-a.akamaihd.net/apps/valve/2007/SIGGRAPH2007_AlphaTestedMagnification.pdf)