#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    vec2 size;
    vec4 inner;
    float innerRadius;

    vec4 island0;
    vec4 island1;
    vec4 island2;
    float islandRadius;

    vec4 panel0;
    vec4 panel1;
    vec4 panel2;
    float panelRadius;
    float smoothing;

    float borderWidth;
    vec4 fillColor;
    vec4 borderColor;

    vec4 cut;

    float panelSmoothing;
};

float sdBox(vec2 p, vec2 center, vec2 halfSize)
{
    vec2 d = abs(p - center) - halfSize;
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

float sdRoundedBox(vec2 p, vec2 center, vec2 halfSize, float radius)
{
    radius = min(radius, min(halfSize.x, halfSize.y));
    vec2 d = abs(p - center) - halfSize + vec2(radius);
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
}

float smin(float a, float b, float k)
{
    return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
}

float rectDistance(vec2 p, vec4 rect, float radius)
{
    if (rect.z < 0.5 || rect.w < 0.5) return 1e10;
    vec2 halfSize = rect.zw * 0.5;
    return sdRoundedBox(p, rect.xy + halfSize, halfSize, radius);
}

void main()
{
    vec2 p = qt_TexCoord0 * size;

    bool inCut = cut.z > 0.5 && cut.w > 0.5 && p.x >= cut.x && p.x < cut.x + cut.z && p.y >= cut.y && p.y < cut.y + cut.w;

    vec2 innerMin = inner.xy;
    vec2 innerMax = size - inner.zw;
    float dInner = sdRoundedBox(p, (innerMin + innerMax) * 0.5, (innerMax - innerMin) * 0.5, innerRadius);
    float dOuter = sdBox(p, size * 0.5, size * 0.5 + vec2(80.0));
    float d = max(dOuter, -dInner);

    d = smin(d, rectDistance(p, island0, islandRadius), smoothing);
    d = smin(d, rectDistance(p, island1, islandRadius), smoothing);
    d = smin(d, rectDistance(p, island2, islandRadius), smoothing);

    d = smin(d, rectDistance(p, panel0, panelRadius), panelSmoothing);
    d = smin(d, rectDistance(p, panel1, panelRadius), panelSmoothing);
    d = smin(d, rectDistance(p, panel2, panelRadius), panelSmoothing);

    float fw = max(fwidth(d), 0.0001);
    float inside = 1.0 - smoothstep(-fw, fw, d);

    float edge = borderWidth > 0.0 ? smoothstep(-borderWidth - fw, -borderWidth + fw, d) : 0.0;
    vec4 surface = mix(fillColor, borderColor, edge * borderColor.a);
    surface.rgb *= surface.a;

    fragColor = inCut ? vec4(0.0) : surface * inside * qt_Opacity;
}
