#!/bin/bash

use_cache=0
if [ -f ~/.config/settings/wallpaper_cache ] ;then
    use_cache=1
fi

if [ "$use_cache" == "1" ] ;then
    echo "using wallpaper cache"
else
    echo "wallpaper cache disabled"
fi

generated_versions="$HOME/.cache/wallpaper-generated"
cache_file="$HOME/.cache/current_wallpaper"
blurred_wallpaper="$HOME/.cache/blurred_wallpaper.png"
square_wallpaper="$HOME/.cache/square_wallpaper.png"
rasi_file="$HOME/.cache/current_wallpaper.rasi"
current_wallpaper="$HOME/.local/share/wallpaper/current"
blur="50x30"

if [ ! -d $generated_versions ] ;then
    mkdir $generated_versions
fi

if [ -z $1 ] ;then
    if [ -f $cache_file ] ;then
        wallpaper=$(cat $cache_file)
    else
        wallpaper=$current_wallpaper
    fi
else
    wallpaper=$1
fi
used_wallpaper=$wallpaper
echo "setting wallpaper with original image $wallpaper"
tmp_wallpaper=$wallpaper

if [ ! -f $cache_file ] ;then
    touch $cache_file
fi
echo "$wallpaper" > $cache_file
echo "path of current wallpaper copied to $cache_file"

wallpaper_filename=$(basename $wallpaper)
echo "wallpaper Filename: $wallpaper_filename"

echo "generate new cached wallpaper blur-$blur-$wallpaper_filename with blur $blur"
magick $used_wallpaper -resize 75% $blurred_wallpaper
echo "resized to 75%"
if [ ! "$blur" == "0x0" ] ;then
    magick $blurred_wallpaper -blur $blur $blurred_wallpaper
    cp $blurred_wallpaper $generated_versions/blur-$blur-$wallpaper_filename.png
    echo "blurred"
fi
cp $generated_versions/blur-$blur-$wallpaper_filename.png $blurred_wallpaper

if [ ! -f $rasi_file ] ;then
    touch $rasi_file
fi
echo "* { current-image: url(\"$blurred_wallpaper\", height); }" > "$rasi_file"

echo "generate new cached wallpaper square-$wallpaper_filename"
magick $tmp_wallpaper -gravity Center -extent 1:1 $square_wallpaper
cp $square_wallpaper $generated_versions/square-$wallpaper_filename.png
