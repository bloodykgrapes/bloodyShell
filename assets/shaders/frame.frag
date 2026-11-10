#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float thickness;
    vec4 startBody;
    vec4 centerBody;
    vec4 endBody;
    vec4 startPanel;
    vec4 centerPanel;
    vec4 endPanel;
    vec4 dockBody;
    vec4 leftBody;
    vec4 rightBody;
    vec2 screenSize;
    float cornerRadius;
    float bodyRadius;
    float smoothing;
    float panelSmoothing;
    vec4 fillColor;
};

float roundedBox(vec2 p, vec2 center, vec2 halfSize, float radius)
{
    radius = min(radius, min(halfSize.x, halfSize.y));
    vec2 d = abs(p - center) - halfSize + radius;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
}

float body(vec2 p, vec4 rect)
{
    if (rect.z <= 0.0 || rect.w <= 0.0) return 1e6;
    return roundedBox(p, rect.xy + rect.zw * 0.5, rect.zw * 0.5, bodyRadius);
}

float joinWith(float a, float b, float amount)
{
    float k = max(0.001, amount);
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

float joinBody(vec2 p, float distance, vec4 rect)
{
    return joinWith(distance, body(p, rect), min(smoothing, min(rect.z, rect.w)));
}

void main()
{
    vec2 p = qt_TexCoord0 * screenSize;
    vec2 halfInner = max(vec2(0.0), screenSize * 0.5 - thickness);
    float d = thickness > 0.0 ? -roundedBox(p, screenSize * 0.5, halfInner, cornerRadius) : 1e6;
    d = joinBody(p, d, startBody);
    d = joinBody(p, d, centerBody);
    d = joinBody(p, d, endBody);
    d = joinWith(d, body(p, startPanel), panelSmoothing);
    d = joinWith(d, body(p, centerPanel), panelSmoothing);
    d = joinWith(d, body(p, endPanel), panelSmoothing);
    d = joinBody(p, d, dockBody);
    d = joinWith(d, body(p, leftBody), panelSmoothing);
    d = joinWith(d, body(p, rightBody), panelSmoothing);
    float aa = max(fwidth(d), 0.001);
    float alpha = 1.0 - smoothstep(-aa, aa, d);
    fragColor = vec4(fillColor.rgb * fillColor.a, fillColor.a) * alpha * qt_Opacity;
}
