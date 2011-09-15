//fragment shader
//performs non maxima suppression on DoG response

varying mediump vec2 tCoord;
uniform mediump float width;
uniform mediump float height;
uniform mediump sampler2D pic0;
uniform mediump sampler2D pic1;
void main(void)
{
	mediump float offseth = 1.0/width;
	mediump float offsetv = 1.0/height;
	
	mediump float thres2=0.1; // minimum difference threshold.
	mediump vec4 vthres=vec4(2.0);
	
	mediump vec4 c=vec4(texture2D(pic0, tCoord).yz,texture2D(pic1, tCoord).xy)*255.0;
	mediump vec4 t;
	
	bvec4 max=greaterThan(c,128.0+vthres);
	bvec4 min=lessThan(c,128.0-vthres);
	mediump vec4 f = vec4(max)-vec4(min);

	lowp vec4 r = step(thres2, f*c-f*vec4(c.yzw, texture2D(pic1, tCoord).z*255.0)) * step(thres2, f*c-f*vec4(texture2D(pic0, tCoord).x*255.0, c.xyz));

	for (int i=-1; i<2; i++) {
		for (int j=-1; j<2; j++) {
			if (i!=0 || j!=0) {
				t = vec4(texture2D(pic0, tCoord+vec2(float(i)*offseth,float(j)*offsetv)).yz,texture2D(pic1, tCoord+vec2(float(i)*offseth,float(j)*offsetv)).xy)*255.0;
				r*= step(thres2, f*c-f*t);
				r*= step(thres2, f*c-f*vec4(t.yzw, texture2D(pic1, tCoord+vec2(float(i)*offseth,float(j)*offsetv)).z*255.0));
				r*= step(thres2, f*c-f*vec4(texture2D(pic0, tCoord+vec2(float(i)*offseth,float(j)*offsetv)).x*255.0, t.xyz));
			}
		}
	}
	gl_FragColor = r;

}