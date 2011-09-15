//fragment shader
//computes orientation and weighted magnitude from gradients

varying mediump vec2 tCoord;
varying mediump vec2 tGauss;
uniform lowp sampler2D gradx;
uniform lowp sampler2D grady;
uniform lowp sampler2D gauss;
uniform int scale;
uniform int theta;
void main(void)
{
	
	mediump float gx=(texture2D(gradx, tCoord)[scale]-0.5)*2.0;
	mediump float gy=(texture2D(grady, tCoord)[scale]-0.5)*2.0;
	mediump float theta = mod((atan(gy,gx)+3.5342917353)/6.2831853072-float(theta)/8.0,1.0); //atan()+pi+pi/8 will allow our angle quantization to be axis-aligned
	mediump float mag = sqrt(gx*gx+gy*gy)*texture2D(gauss, tGauss).w/1.4142135624;
	gl_FragColor = vec4(theta, mag, 0.0, 0.0);
}