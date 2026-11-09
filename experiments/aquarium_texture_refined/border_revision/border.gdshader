shader_type canvas_item;
render_mode unshaded;
uniform int view=0;
void fragment(){
 vec2 p=UV;
 vec3 red=vec3(.59,.145,.105);
 red+=vec3(.008,.005,.003)*sin(p.x*TAU*2.)*sin(p.y*TAU);
 // Symmetric painted edge tone, without a baked directional light or shadow.
 float rim=1.-smoothstep(.025,.045,min(p.y,1.-p.y));
 vec3 color=mix(red,red*.82,rim);
 if(view==0){
  vec2 q=vec2(fract(p.x*3.)-.5,(p.y-.5)*.75);
  float r=length(q);float aa=max(fwidth(r),.002);
  float stud=1.-smoothstep(.086-aa,.086+aa,r);
  color=mix(color,vec3(.57,.39,.13),stud);
  color=mix(color,vec3(.84,.65,.29),1.-smoothstep(.068-aa,.068+aa,r));
 }
 COLOR=vec4(color,1.);
}
