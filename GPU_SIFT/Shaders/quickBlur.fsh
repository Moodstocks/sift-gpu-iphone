//fragment shader that computes either vertical or horizontal smoothing, with the same sigma for all channels.

varying mediump vec2 tCoord;
uniform lowp sampler2D Image;
uniform lowp float Coeff[13];
uniform mediump vec2 dir;
void main(void)
{
	mediump float colors[13];
	for (int i=0; i<13; i++) {
		colors[i]=texture2D(Image, tCoord+(float(i)-6.0)*dir).x;
	}
	mediump float r=0.0;
	for (int i=0; i<13; i++) {
		r+=Coeff[i]*colors[i];
	}
	gl_FragColor = vec4(r);
}