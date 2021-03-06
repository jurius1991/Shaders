//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// UIDetect by brussell
// v. 2.0.1
// License: CC BY 4.0
//
// UIDetect is configured via the file UIDectect.fxh. Please look
// there for a full description and usage of this shader.
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#include "ReShadeUI.fxh"

uniform float fPixelPosX < __UNIFORM_SLIDER_FLOAT1
    ui_label = "Pixel X-Position";
    ui_category = "Show Pixel";
    ui_min = 0; ui_max = BUFFER_WIDTH;
    ui_step = 1;
> = 100;

uniform float fPixelPosY < __UNIFORM_SLIDER_FLOAT1
    ui_label = "Pixel Y-Position";
    ui_category = "Show Pixel";
    ui_min = 0; ui_max = BUFFER_HEIGHT;
    ui_step = 1;
> = 100;

#include "ReShade.fxh"
#include "UIDetect.fxh"

#define epsilon 0.00001

//textures and samplers
texture texColorOrig { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };
sampler ColorOrig { Texture = texColorOrig; };

texture texUIDetect { Width = 1; Height = 1; Format = R8; };
sampler UIDetect { Texture = texUIDetect; };

#if (UIDetect_USE_RGB_MASK == 1)
    texture texUIDetectMask <source="UIDetectMaskRGB.png";>
    { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format=RGBA8; };
    sampler UIDetectMask { Texture = texUIDetectMask; };
#endif

//pixel shaders
float3 PS_ShowPixel(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float2 pixelCoord = float2(fPixelPosX, fPixelPosY) * BUFFER_PIXEL_SIZE;
    float3 pixelColor = tex2Dlod(ReShade::BackBuffer, float4(pixelCoord, 0, 0)).xyz;
    return pixelColor;
}

float PS_UIDetect(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 pixelColor, uiPixelColor;
    float2 pixelCoord;
    float diff;
    float ui = 1;
    bool uiDetected = false;
    bool uiNext = false;

    for (int i=0; i < PIXELNUMBER; i++)
    {
        [branch]
        if (UIPixelCoord_UINr[i].z - ui < epsilon){
            if (uiNext == false){
                pixelCoord = UIPixelCoord_UINr[i].xy * BUFFER_PIXEL_SIZE;
                pixelColor = round(tex2Dlod(ReShade::BackBuffer, float4(pixelCoord, 0, 0)).rgb * 255);
                uiPixelColor = UIPixelRGB[i].rgb;
                diff = abs(dot(pixelColor - uiPixelColor, 0.333));
                if (diff < epsilon) {
                    uiDetected = true;
                }else{
                    uiDetected = false;
                    uiNext = true;
                }
            }
        }else{
            if (uiDetected == true){ return ui * 0.1; }
            ui += 1;
            uiNext = false;
            i -= 1;
        }
    }
    return uiDetected * ui * 0.1;
}

float4 PS_StoreColor(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return tex2D(ReShade::BackBuffer, texcoord);
}

float4 PS_RestoreColor(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float ui = tex2D(UIDetect, float2(0,0)).x;
    float4 colorOrig = tex2D(ColorOrig, texcoord);
    float4 color = tex2D(ReShade::BackBuffer, texcoord);
    
    #if (UIDetect_USE_RGB_MASK == 1)
        float3 uiMaskRGB = 1 - tex2D(UIDetectMask, texcoord).rgb;
        float3 uiMask = 0;

        if      (ui > .39) uiMask = 1;            //UI-Nr >3 -> apply no mask
        else if (ui > .29) uiMask = uiMaskRGB.b;  //UI-Nr  3 -> apply masklayer blue
        else if (ui > .19) uiMask = uiMaskRGB.g;  //UI-Nr  2 -> apply masklayer green
        else if (ui > .09) uiMask = uiMaskRGB.r;  //UI-Nr  1 -> apply masklayer red
        color.rgb = lerp(color.rgb, colorOrig.rgb, uiMask);
    #else
        color = ui > epsilon ? colorOrig : color;
    #endif
    return color;
}

//techniques
technique UIDetect_ShowPixel
{
    pass {
        VertexShader = PostProcessVS;
        PixelShader = PS_ShowPixel;
    }
}

technique UIDetect
{
    pass {
        VertexShader = PostProcessVS;
        PixelShader = PS_UIDetect;
        RenderTarget = texUIDetect;
    }
}

technique UIDetect_Before
{
    pass {
        VertexShader = PostProcessVS;
        PixelShader = PS_StoreColor;
        RenderTarget = texColorOrig;
    }
}

technique UIDetect_After
{
    pass {
        VertexShader = PostProcessVS;
        PixelShader = PS_RestoreColor;
    }
}
