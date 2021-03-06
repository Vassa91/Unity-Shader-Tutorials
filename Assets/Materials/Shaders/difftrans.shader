Shader "Custom/DiffuseHighlights"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
        _HighlightColor("Hightlight Color", Color) = (1, 1, 1, 1)
        _HighlightExtrusion("Highlight Size", float) = 0.08
        _HighlightScale("Highlight Scale", float) = -1
        _BrightColor("Light Color", Color) = (1, 1, 1, 1)
        _DarkColor("Dark Color", Color) = (1, 1, 1, 1)
        _AmbientIntensity("Ambient Intensity", Range(0,1)) = 1.0
        _Distortion("Scattering Distortion", Range(0,1)) = 0.5
        _Power("Scattering Power", float) = 1.0
        _Scale("Scattering Scale", float) = 1.0
	}

	SubShader
	{
        // Outline pass
        Pass
        {
            Cull Front 

            CGPROGRAM
            #pragma vertex vert
			#pragma fragment frag

			// Properties
			uniform float4 _HighlightColor;
			uniform float _HighlightExtrusion;
            uniform float _HighlightScale;
			sampler2D _MainTex;

			struct vertexInput
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float3 texCoord : TEXCOORD0;
				float4 color : TEXCOORD1;
			};

			struct vertexOutput
			{
				float4 pos : SV_POSITION;
				float4 color : TEXCOORD0;
			};

			vertexOutput vert(vertexInput input)
			{
				vertexOutput output;

				float4 newPos = input.vertex;

                // _WorldSpaceLightPos0 provided by Unity
				float4 lightDir = normalize(_WorldSpaceLightPos0);

				// normal extrusion technique
				float3 normal = normalize(input.normal);
				newPos += (float4(normal, 0.0) + lightDir*_HighlightScale) * _HighlightExtrusion;

				// convert to world space
				output.pos = UnityObjectToClipPos(newPos);

				return output;
			}

			float4 frag(vertexOutput input) : COLOR
			{
				return _HighlightColor;
			}
            ENDCG
        }

		// Regular color & lighting pass
		Pass
		{
            Tags
			{ 
				"LightMode" = "ForwardBase" // allows shadow rec/cast, lighting
			}

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase // shadows
			#include "AutoLight.cginc"
			#include "UnityCG.cginc"
			
			// Properties
			sampler2D _MainTex;
            float4 _Color;
			float4 _LightColor0; // provided by Unity
            float4 _BrightColor;
            float4 _DarkColor;
            float _AmbientIntensity;
            float _Distortion;
            float _Power;
            float _Scale;

			struct vertexInput
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float3 texCoord : TEXCOORD0;
			};

			struct vertexOutput
			{
				float4 pos : SV_POSITION;
				float3 normal : NORMAL;
				float3 texCoord : TEXCOORD0;
                float3 viewDir: TEXCOORD1;
				LIGHTING_COORDS(2,3) // shadows
			};

			vertexOutput vert(vertexInput input)
			{
				vertexOutput output;

				output.pos = UnityObjectToClipPos(input.vertex);
				float4 normal4 = float4(input.normal, 0.0);
				output.normal = normalize(mul(normal4, unity_WorldToObject).xyz);
                output.viewDir = normalize(_WorldSpaceCameraPos - mul(unity_ObjectToWorld, input.vertex).xyz);

				output.texCoord = input.texCoord;

				TRANSFER_SHADOW(output); // shadows
				return output;
			}

			float4 frag(vertexOutput input) : COLOR
			{
				// _WorldSpaceLightPos0 provided by Unity
				float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);

				// get dot product between surface normal and light direction
				float lightDot = saturate(dot(input.normal, lightDir));
                // lerp lighting between light & dark value
                float3 light = lerp(_DarkColor, _BrightColor, lightDot);

				// sample texture for color
				float4 albedo = tex2D(_MainTex, input.texCoord.xy);

                // shadow value
                float attenuation = LIGHT_ATTENUATION(input); 

                // composite all lighting together
                float3 lighting = light * attenuation;
                // add in ambient lighting
                lighting += ShadeSH9(half4(input.normal,1)) * _AmbientIntensity;
                
                // multiply albedo and lighting
				float3 rgb = albedo.rgb * lighting;

                // translucency
                float3 h = normalize(lightDir + input.normal * _Distortion);
                float i = pow(saturate(dot(input.viewDir, h)), _Power) * _Scale;
                rgb += albedo * i;

				return float4(rgb, 1.0);
			}

			ENDCG
		}

		// Shadow pass
		Pass
    	{
            Tags 
			{
				"LightMode" = "ShadowCaster"
			}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

            struct v2f { 
                V2F_SHADOW_CASTER;
            };

            v2f vert(appdata_base v)
            {
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
    	}
	}
    Fallback "Diffuse"
}