//fragment shader
//substracts two gaussians to create DoG

varying mediump vec2 tCoord;
uniform mediump sampler2D pic;

void main(void)
{
	mediump vec4 r = vec4(texture2D(pic, tCoord).yzw-texture2D(pic, tCoord).xyz, 0.0);
	gl_FragColor = r*6.0+0.5;
}