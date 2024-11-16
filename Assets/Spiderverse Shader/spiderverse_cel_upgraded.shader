//Writen by Satriyo Aji Nugroho
//Rigged Box Softworks Studio

Shader "Custom/spiderverse_cel_upgraded"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BumpMap ("Bumpmap", 2D) = "bump" {}
        
        // Color mask and emissive properties
        _ColorMaskTex ("Color Mask Texture", 2D) = "white" {}
        _ColorMaskRed ("Red Channel Color", Color) = (1, 0, 0, 1)
        _ColorMaskGreen ("Green Channel Color", Color) = (0, 1, 0, 1)
        _ColorMaskBlue ("Blue Channel Color", Color) = (0, 0, 1, 1)
        _ColorMaskOverlayStrength ("Color Mask Overlay Strength", Range(0, 1)) = 0.5
        _EmissiveColor ("Emissive Color", Color) = (1, 1, 1, 1)
        _EmissiveTex ("Emissive Texture", 2D) = "white" {}
        _EmissiveIntensity ("Emissive Intensity", Range(0, 10)) = 1

        // Rim lighting properties
        _RimColor ("Rim Color", Color) = (1, 1, 1, 1)
        _RimStrength ("Rim Strength", Range(0, 5)) = 1.5

        // Halftone properties
        _HalftoneColor ("Halftone Color", Color) = (1, 1, 1, 1) // New color input for halftone
        _HalftoneRadius ("Halftone Radius", Range(1, 50)) = 10 // Size of the halftone pattern
        _HalftoneStrength ("Halftone Strength", Range(0, 1)) = 0.5 // How much halftone affects the result

        // Ben-day process
        _LightenScale("_LightenScale", Range(0,1)) = 0.5
        _DarkenScale("_DarkenScale", Range(0,1)) = 0.5
        _Rotation("Rotation", Range(0,360)) = 0
        _cScale("cScale", Range(1,200)) = 50
        _lScale("lScale", Range(1,200)) = 50
        _MinRadius("_MinRadius", Range(0,1)) = .1 // if lower than this value, no circle is shown

        // Cel shading 
        _Step("Step", Int) = 4
        _ClampA("_ClampA", Range(0,1)) = .2
        _ClampB("_ClampB", Range(0,1)) = .8
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM

        #include "UnityCG.cginc"
        #pragma surface surf Custom
        #pragma target 3.0

        sampler2D _MainTex;
        sampler2D _BumpMap;
        sampler2D _ColorMaskTex;
        sampler2D _EmissiveTex;

        float _Rotation;
        float _cScale;
        float _lScale;
        float _LightenScale;
        float _DarkenScale;
        int _Step;
        float _ClampA;
        float _ClampB;
        float _MinRadius;
        fixed4 _EmissiveColor;
        float _EmissiveIntensity;

        // Color mask color inputs for RGB channels
        fixed4 _ColorMaskRed;
        fixed4 _ColorMaskGreen;
        fixed4 _ColorMaskBlue;
        
        // Color mask overlay strength
        float _ColorMaskOverlayStrength;

        // Rim lighting properties
        fixed4 _RimColor;
        float _RimStrength;

        // Halftone properties
        fixed4 _HalftoneColor;
        float _HalftoneRadius;
        float _HalftoneStrength;

        struct Input
        {
            float2 uv_MainTex;
            float3 vertex;
            float3 viewDir;
            float3 vertexNormal;
            float4 screenPos;
            float2 uv_BumpMap;
            float2 uv_ColorMaskTex;
            float2 uv_EmissiveTex;
        };

        struct SurfaceOutputCustom {
            fixed3 Albedo;
            fixed3 Normal;
            fixed3 Emission;
            fixed Alpha;
            float2 textureCoordinate;
            fixed3 RimLighting;
        };

        float circle(float2 st, float radius) {
            float d = distance(st, float2(0.5, 0.5)) * sqrt(2);
            return step(d, radius);
        }

        float2 rotate(float2 p, float theta) {
            return float2(p.x * cos(theta) - p.y * sin(theta),
                          p.x * sin(theta) + p.y * cos(theta));
        }

        // Halftone function: generates a halftone effect based on the texture coordinates
        float halftone(float2 st, float radius) {
            // Use a pattern generator based on the fractional part of the coordinates
            float pattern = frac(st.x * radius) * frac(st.y * radius);
            return step(0.5, pattern); // Halftone pattern with 50% threshold
        }

        void surf(Input IN, inout SurfaceOutputCustom o) {
            float4 tex = tex2D(_MainTex, IN.uv_MainTex);

            float2 textureCoordinate = IN.screenPos.xy / IN.screenPos.w;
            float aspect = _ScreenParams.x / _ScreenParams.y;
            textureCoordinate.x = textureCoordinate.x * aspect;

            // Apply the color mask (using RGB color values directly)
            float4 colorMask = tex2D(_ColorMaskTex, IN.uv_ColorMaskTex);
            fixed3 colorMaskRed = _ColorMaskRed.rgb * colorMask.r;
            fixed3 colorMaskGreen = _ColorMaskGreen.rgb * colorMask.g;
            fixed3 colorMaskBlue = _ColorMaskBlue.rgb * colorMask.b;
            
            // Combine the color mask channels to affect the base texture color
            o.Albedo = tex.rgb * (colorMaskRed + colorMaskGreen + colorMaskBlue);

            // Apply the color mask overlay strength (blend between base color and mask)
            o.Albedo = lerp(o.Albedo, tex.rgb, _ColorMaskOverlayStrength);

            // Apply the halftone effect with the specified color
            float2 st = textureCoordinate * _HalftoneRadius;
            float halftoneEffect = halftone(st, _HalftoneRadius);
            o.Albedo = lerp(o.Albedo, _HalftoneColor.rgb, halftoneEffect * _HalftoneStrength);

            // Handle emissive texture and color
            float4 emissiveTex = tex2D(_EmissiveTex, IN.uv_EmissiveTex);
            o.Emission = emissiveTex.rgb * _EmissiveColor.rgb * _EmissiveIntensity;

            // Calculate rim lighting effect
            float rim = 1.0 - saturate(dot(o.Normal, IN.viewDir));
            o.RimLighting = _RimColor.rgb * pow(rim, _RimStrength);

            o.textureCoordinate = textureCoordinate;
            o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
            o.Alpha = 1;
        }

        half4 LightingCustom(SurfaceOutputCustom s, half3 lightDir, half3 viewDir) {
            float2 st = rotate(s.textureCoordinate, _Rotation * 3.14 / 180);

            float2 cst = frac(st * (_cScale * abs(_WorldSpaceCameraPos.z)));
            float2 lst = frac(st * (_lScale * abs(_WorldSpaceCameraPos.z)));

            float NdotL = dot(s.Normal, lightDir);
            // Circle pattern
            float circles = circle(cst, step(_MinRadius, NdotL) * NdotL);
            // Line pattern NdotL*-1 to draw these where the sun doesn't shine
            float lines = step(lst.x, -NdotL);
            // Cel shading with clamps
            half cel = clamp(ceil(max(NdotL, 0) * _Step) / _Step, _ClampA, _ClampB);

            half4 col;
            half3 l = (s.Albedo * _LightColor0.rgb * cel);
            half3 lDark = (1 - _DarkenScale) * l;
            half3 lBright = 1 - ((1 - _LightenScale) * (1 - l));

            // Combine lighting, emissive, and rim lighting
            col.rgb = (1 - (circles + lines)) * l + circles * lBright + lines * lDark + s.Emission + s.RimLighting;
            col.a = s.Alpha;

            return col;
        }

        ENDCG
    }
    FallBack "Diffuse"
}
