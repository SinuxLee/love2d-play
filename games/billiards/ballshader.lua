-- Sphere projection shader for billiard balls
-- Equirectangular UV (120x60) -> sphere with 3D rotation + cinematic lighting.

local BallShader = {}

local shader = nil

function BallShader.init()
    shader = love.graphics.newShader([[
        uniform float rollX;
        uniform float rollY;
        uniform float rollZ;

        const float PI = 3.14159265;

        vec4 effect(vec4 color, Image tex, vec2 texCoord, vec2 screenCoord) {
            vec2 uv = texCoord * 2.0 - 1.0;
            float r2 = dot(uv, uv);

            // Anti-aliased edge: smooth fade over ~1.5 pixels at the sphere boundary
            float radius = length(uv);
            float pixelWidth = fwidth(radius);
            float edgeAlpha = 1.0 - smoothstep(1.0 - pixelWidth * 1.5, 1.0 + pixelWidth * 0.5, radius);

            if (edgeAlpha < 0.001) return vec4(0.0);

            // Clamp r2 for sphere math (avoid sqrt of negative at very edge)
            r2 = min(r2, 0.999);
            float z = sqrt(1.0 - r2);
            vec3 pos = vec3(uv.x, -uv.y, z);

            // ---- 3D rotation: Z -> Y -> X ----
            float cz = cos(rollZ), sz = sin(rollZ);
            pos = vec3(pos.x*cz - pos.y*sz, pos.x*sz + pos.y*cz, pos.z);

            float cy = cos(rollY), sy = sin(rollY);
            pos = vec3(pos.x*cy + pos.z*sy, pos.y, -pos.x*sy + pos.z*cy);

            float cx = cos(rollX), sx = sin(rollX);
            pos = vec3(pos.x, pos.y*cx - pos.z*sx, pos.y*sx + pos.z*cx);

            // ---- Equirectangular UV ----
            float lon = atan(pos.x, pos.z);
            float lat = asin(clamp(pos.y, -1.0, 1.0));
            vec2 sphereUV = vec2(lon / (2.0*PI) + 0.5, -lat / PI + 0.5);
            vec4 ballColor = Texel(tex, sphereUV);

            // ---- Lighting (screen-fixed, NOT rotating) ----
            vec3 N = vec3(uv.x, -uv.y, z);
            vec3 V = vec3(0.0, 0.0, 1.0);

            // -- Key light: overhead, from top-left, warm --
            vec3 L1 = normalize(vec3(-0.3, 0.55, 0.85));
            float NdotL1 = dot(N, L1);
            float wrap1 = max((NdotL1 + 0.4) / 1.4, 0.0);
            vec3 H1 = normalize(L1 + V);
            float spec1 = pow(max(dot(N, H1), 0.0), 150.0);

            // -- Fill light: opposite side, cooler, softer --
            vec3 L2 = normalize(vec3(0.35, -0.25, 0.65));
            float NdotL2 = dot(N, L2);
            float wrap2 = max((NdotL2 + 0.4) / 1.4, 0.0);
            vec3 H2 = normalize(L2 + V);
            float spec2 = pow(max(dot(N, H2), 0.0), 100.0);

            // -- Third accent light: from below-right, very subtle --
            vec3 L3 = normalize(vec3(0.5, -0.6, 0.4));
            float wrap3 = max((dot(N, L3) + 0.3) / 1.3, 0.0);

            // Diffuse combination
            float ambient = 0.22;
            float diffuse = ambient
                + wrap1 * 0.52
                + wrap2 * 0.18
                + wrap3 * 0.08;

            // ---- Specular: bright, sharp, billiard ball gloss ----
            // Key light specular (white, strong)
            float specTotal = spec1 * 0.85 + spec2 * 0.3;

            // ---- Fresnel rim light ----
            float fresnel = pow(1.0 - z, 3.0);
            // Tint rim with the ball's own color for a subtle colored edge glow
            vec3 rimColor = mix(vec3(1.0), ballColor.rgb, 0.35) * fresnel * 0.4;

            // ---- Ambient occlusion ----
            float ao = 0.55 + 0.45 * smoothstep(0.0, 0.7, z);

            // ---- Glossy environment sheen (top face catches overhead light) ----
            float envSheen = smoothstep(0.15, 0.95, z) * 0.08;

            // ---- Subsurface scattering hint (colored balls glow slightly at edges) ----
            float sss = pow(1.0 - z, 2.0) * 0.08;
            vec3 sssColor = ballColor.rgb * sss;

            // ---- Combine ----
            vec3 lit = ballColor.rgb * diffuse * ao;    // base lit color
            lit += vec3(specTotal);                       // specular highlights
            lit += rimColor;                              // colored rim glow
            lit += sssColor;                              // subsurface hint
            lit += vec3(envSheen);                         // environment sheen

            // Contrast boost: push darks darker and lights brighter
            lit = pow(lit, vec3(0.92));

            // Saturation boost
            float gray = dot(lit, vec3(0.299, 0.587, 0.114));
            lit = mix(vec3(gray), lit, 1.2);

            return vec4(clamp(lit, 0.0, 1.0), edgeAlpha) * color;
        }
    ]])

    return shader ~= nil
end

function BallShader.isAvailable()
    return shader ~= nil
end

function BallShader.drawBall(uvImage, x, y, rx, ry, rz, scale, radius)
    if not shader or not uvImage then return false end

    scale = scale or 1.0
    local size = radius * 2 * scale

    shader:send("rollX", rx or 0)
    shader:send("rollY", ry or 0)
    shader:send("rollZ", rz or 0)

    love.graphics.setShader(shader)
    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.draw(uvImage, x - size / 2, y - size / 2, 0,
        size / uvImage:getWidth(), size / uvImage:getHeight())

    love.graphics.setShader()
    return true
end

return BallShader
