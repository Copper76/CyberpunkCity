Shader "Unlit/RainDrops"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Size ("Size", float) = 1.0
        _T("Manual Time", float) = 1.0
        _UVSpeed("UV Move Speed", float) = 0.25
        _TrailFrac("Trail Fraction", float) = 8
        _Distortion("Distortion", range(-5,5)) = 1.0
        _Blur("Blur", range(0,1)) = 1.0
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Opaque" }
        LOD 200

        GrabPass
        {
            "_GrabTexture"
        }

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #define S(a, b, t) smoothstep(a, b, t)

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 grabUV : TEXCOORD1;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex, _GrabTexture;
            float4 _MainTex_ST;
            float _Size;
            float _T;
            float _TrailFrac;
            float _UVSpeed;
            float _Distortion;
            float _Blur;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.grabUV = UNITY_PROJ_COORD(ComputeGrabScreenPos(o.vertex));
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            float N21(float2 p)
            {
                p = frac(p * float2(123.34, 345.45));
                p += dot(p, p+31.415);
                return frac(p.x*p.y);
            }

            float3 Layer(float2 UV, float t)
            {
                float2 aspect = float2(2, 1);
                float2 uv = UV * _Size * aspect;
                uv.y += t * _UVSpeed; // tweak value

                float2 gv = frac(uv) - 0.5f;
                float2 id = floor(uv);

                float rand = N21(id);

                t += rand * 6.2831;

                float w = UV.y * 10;
                float x = (rand - 0.5) * 0.9;
                x += (0.45 - abs(x)) * sin(3 * w) * pow(sin(w), 6) * 0.45;
                float y = -sin(t + sin(t + sin(t) * 0.5)) * 0.45;
                y -= (gv.x - x) * (gv.x - x);

                float2 dropPos = (gv - float2(x,y)) / aspect;
                float drop = S(0.05, 0.03, length(dropPos));

                float2 trailPos = (gv - float2(x,t * _UVSpeed)) / aspect;
                trailPos.y = (frac(trailPos.y * _TrailFrac) - 0.5) / _TrailFrac;
                float trail = S(0.03, 0.01, length(trailPos));
                float fogTrail = S(-0.05, 0.05, dropPos.y);
                fogTrail *= S(0.5, y, gv.y);

                trail *= fogTrail;
                fogTrail *= S(0.05f, 0.04f, abs(dropPos.x));

                float2 offset = drop * dropPos + trail * trailPos;

                return float3(offset, fogTrail);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float t = fmod(_Time.y, 3600);
                float4 col = 0;

                float3 drops = Layer(i.uv, t);
                drops += Layer(i.uv * 1.53 + 7.42, t);

                float fade = 1 - saturate(fwidth(i.uv) * 50);

                float blur = _Blur * 7 * (1-drops.z * fade);
                blur *= 0.01;

                // col = tex2Dlod(_GrabTexture, float4(projUV + drops.xy * _Distortion, 0, blur));

                float2 projUV = i.grabUV.xy / i.grabUV.w;
                projUV += drops.xy * _Distortion * fade;

                const float numSamples = 32;
                float a = N21(i.uv) * 6.2831;
                for (float i=0; i<numSamples; i++)
                {
                    float2 offset = float2(sin(a), cos(a)) * blur;
                    offset *= sqrt(frac(sin((i+1) * 578) * 5627));
                    col += tex2D(_GrabTexture, projUV + offset);
                    a++;
                }
                col /= numSamples;
                // col = tex2D(_GrabTexture, projUV);

                return col;
            }
            ENDCG
        }
    }
}
