#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(binding = 1) uniform sampler2D wallpaperTexture;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float inset;
    vec4 startShape;
    vec4 startCorners;
    vec4 startFillets;
    vec4 centerShape;
    vec4 centerCorners;
    vec4 centerFillets;
    vec4 endShape;
    vec4 endCorners;
    vec4 endFillets;
    vec4 panelShape;
    vec4 panelCorners;
    vec4 panelFillets;
    vec4 dockShape;
    vec4 dockCorners;
    vec4 dockFillets;
    vec2 screenSize;
    float cornerRadius;
    float smoothing;
    float barSmoothing;
    float menuSide;
    vec4 centerJoin;
    vec4 paintColor;
    float borderWidth;
    vec4 borderColor;
    vec2 wallpaperScale;
    float wallpaperStrength;
};

float roundedBox(vec2 p, vec2 center, vec2 halfSize, float radius)
{
    radius = min(radius, min(halfSize.x, halfSize.y));
    vec2 d = abs(p - center) - halfSize + radius;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
}

float bodyDistance(vec2 p, vec4 rect, vec4 corners, bool joined)
{
    vec2 side = step(rect.xy + rect.zw * 0.5, p);
    float radius = mix(mix(corners.x, corners.y, side.x), mix(corners.z, corners.w, side.x), side.y);
    vec2 start = rect.xy;
    vec2 end = start + rect.zw;
    // Paint under the frame at contact so the shared edge draws no border.
    if (joined) {
        start = mix(start, min(start, vec2(-2.0)), step(start, vec2(inset)));
        end = mix(end, max(end, screenSize + 2.0), step(screenSize - inset, end));
    }
    return roundedBox(p, (start + end) * 0.5, (end - start) * 0.5, radius);
}

float fillet(float distance, float fromEdge, float fromBodySide, float radius)
{
    if (radius <= 0.0 || fromEdge >= radius || fromBodySide >= radius || fromEdge <= -4.0 || fromBodySide <= -4.0)
        return distance;
    vec2 offset = vec2(fromEdge, fromBodySide);
    float curve = radius - length(vec2(radius) - offset);
    // Blend back into the interior distance so the outline stays antialiased through the join.
    vec2 blend = smoothstep(vec2(-4.0), vec2(0.0), offset);
    return mix(distance, min(distance, curve), blend.x * blend.y);
}

float joinBody(vec2 p, float distance, vec4 rect, vec4 corners, vec4 fillets, float amount)
{
    if (rect.z <= 0.0 || rect.w <= 0.0) return distance;
    bool joined = inset > 0.0 && amount > 0.0;
    distance = min(distance, bodyDistance(p, rect, corners, joined));
    if (!joined) return distance;

    vec2 fromBodySide = max(rect.xy - p, p - (rect.xy + rect.zw));
    vec2 farEdge = screenSize - inset;
    distance = fillet(distance, p.y - inset, fromBodySide.x, fillets.x);
    distance = fillet(distance, farEdge.y - p.y, fromBodySide.x, fillets.y);
    distance = fillet(distance, p.x - inset, fromBodySide.y, fillets.z);
    return fillet(distance, farEdge.x - p.x, fromBodySide.y, fillets.w);
}

float joinMenu(vec2 p, float distance, vec4 panel, vec4 attachment)
{
    if (max(attachment.y, attachment.z) <= 0.0) return distance;

    bool horizontal = menuSide < 2.0;
    bool far = menuSide == 1.0 || menuSide == 3.0;
    float along = horizontal ? p.x : p.y;
    float across = horizontal ? p.y : p.x;
    float fromEdge = far ? attachment.x - across : across - attachment.x;
    float start = ceil(horizontal ? panel.x : panel.y);
    float end = floor(horizontal ? panel.x + panel.z : panel.y + panel.w);
    distance = fillet(distance, fromEdge, start - along, attachment.y);
    return fillet(distance, fromEdge, along - end, attachment.z);
}

void main()
{
    vec2 p = qt_TexCoord0 * screenSize;
    vec2 halfInner = max(vec2(0.0), screenSize * 0.5 - inset);
    float d = inset > 0.0 ? -roundedBox(p, screenSize * 0.5, halfInner, cornerRadius) : 1e6;
    d = joinBody(p, d, startShape, startCorners, startFillets, barSmoothing);
    d = joinBody(p, d, centerShape, centerCorners, centerFillets, smoothing);
    d = joinBody(p, d, endShape, endCorners, endFillets, barSmoothing);
    d = joinBody(p, d, panelShape, panelCorners, panelFillets, smoothing);
    d = joinMenu(p, d, panelShape, centerJoin);
    d = joinBody(p, d, dockShape, dockCorners, dockFillets, smoothing);
    float aa = max(fwidth(d) * 0.5, 0.001);
    float alpha = 1.0 - smoothstep(-aa, aa, d);
    float edge = borderWidth > 0.0 ? smoothstep(-borderWidth - aa, -borderWidth + aa, d) : 0.0;
    vec4 stroke = borderColor * edge;
    vec4 fill = paintColor;
    if (wallpaperStrength > 0.0) {
        vec4 wallpaper = texture(wallpaperTexture, (qt_TexCoord0 - 0.5) * wallpaperScale + 0.5);
        fill.rgb = mix(fill.rgb, wallpaper.rgb * fill.a, wallpaperStrength * wallpaper.a);
    }
    vec4 surface = stroke + fill * (1.0 - stroke.a);
    fragColor = surface * alpha * qt_Opacity;
}
