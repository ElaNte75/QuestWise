# Draws the arrow textures of UI/Arrow.lua into Textures/Arrow_<Name>.tga (64x64, white, tinted in game).
# Usage: python -I _tools/make_arrows.py <add-on folder>   (new files need a full game restart)
import sys
from PIL import Image, ImageDraw, ImageFont, ImageChops
N=256
# white shapes: the add-on tints them with the chosen colour (SetVertexColor); the dark edge stays dark
GOLD=(255,255,255,255); GOLD_D=(190,190,190,255); EDGE=(20,20,20,255); GREY=(120,120,120,255); GREY_D=(85,85,85,255)
SHAPES = {
 "Classic": [[(128,14),(226,226),(128,178),(30,226)]],
 "Chevron": [[(128,22),(234,148),(194,190),(128,114),(62,190),(22,148)]],
 "Block":   [[(128,14),(226,120),(166,120),(166,242),(90,242),(90,120),(30,120)]],
 "Double":  [[(128,14),(222,110),(186,146),(128,90),(70,146),(34,110)],
            [(128,104),(222,200),(186,236),(128,180),(70,236),(34,200)]],
 "Slim":    [[(128,8),(186,236),(128,200),(70,236)]],
 "Needle":  None,
}
K=0.84
def sc(pts): return [(128+(x-128)*K,128+(y-128)*K) for x,y in pts]
def shape_img(name):
    big=Image.new("RGBA",(N,N),(0,0,0,0)); d=ImageDraw.Draw(big)
    if name=="Needle":
        top=sc([(128,6),(170,128),(86,128)]); bot=sc([(86,128),(170,128),(128,250)])
        d.polygon(top+[], outline=EDGE, width=16); d.polygon(bot, outline=EDGE, width=16)
        d.polygon(top, fill=GOLD); d.polygon(bot, fill=GREY)
        d.polygon(sc([(128,6),(170,128),(128,128)]), fill=GOLD_D); d.polygon(sc([(128,128),(170,128),(128,250)]), fill=GREY_D)
        d.ellipse((116,116,140,140), fill=EDGE)
    else:
        polys=[sc(p) for p in SHAPES[name]]
        for p in polys: d.polygon(p, outline=EDGE, width=18)
        for p in polys: d.polygon(p, fill=GOLD)
        # right half darker = simple 3D look
        mask=Image.new("L",(N,N),0); md=ImageDraw.Draw(mask)
        for p in polys: md.polygon(p, fill=255)
        half=Image.new("L",(N,N),0); ImageDraw.Draw(half).rectangle((128,0,N,N),fill=255)
        dark=Image.new("RGBA",(N,N),GOLD_D)
        big.paste(dark,(0,0),ImageChops.multiply(mask,half))
    return big.resize((64,64),Image.LANCZOS)

if __name__=="__main__":
    import os
    out=os.path.join(sys.argv[1],"Textures"); os.makedirs(out,exist_ok=True)
    for n in SHAPES:
        shape_img(n).save(os.path.join(out,"Arrow_"+n+".tga"))
        print("Arrow_"+n+".tga")
