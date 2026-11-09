// Physical structure, never height inferred from pigment brightness.
// The baker prepends the approved artwork functions and its exact Voronoi search.
uniform int response_pass=0;
uniform vec2 texel=vec2(.001953125);
uniform vec2 physical_repeat=vec2(1.8);
uniform float height_range=.008;
float raised_frame(vec2 p,float width){
 vec2 d=min(p,1.-p);
 return 1.-smoothstep(width-.008,width+.008,min(d.x,d.y));
}
float wall_fitting(vec2 p){
 vec2 corner=min(p,1.-p);
 float bracket=max(rect(corner,vec2(.103,.16),vec2(.010,.075)),rect(corner,vec2(.16,.103),vec2(.075,.010)));
 float curl=stroke(spiral_distance((corner-vec2(.185,.185))*3.6),.018);
 return max(bracket,curl);
}
float facade_fitting(vec2 p){
 vec2 corner=min(p,1.-p);
 return max(rect(corner,vec2(.055,.075),vec2(.015,.040)),rect(corner,vec2(.075,.055),vec2(.040,.015)));
}
float stud_mask(vec2 uv){
 vec2 q=vec2(fract(uv.x*3.)-.5,(uv.y-.5)*.75);
 return 1.-smoothstep(.077,.086,length(q));
}
float roof_height(vec2 uv){
 vec2 f=fract(uv*vec2(6,4));
 float rib=1.-smoothstep(.17,.235,abs(f.x-.5));
 float rounded=sqrt(max(0.,1.-pow((f.x-.5)/.24,2.)));
 float end=.83+.056*cos((f.x-.5)*TAU);
 float overlap=smoothstep(.006,.045,f.y)*(1.-smoothstep(end-.025,end+.012,f.y));
 float edge=smoothstep(.003,.018,min(f.x,1.-f.x));
 return .28+edge*(.20*overlap+.24*rounded*rib);
}
float design_height(vec2 uv){
 if(item==1){
  vec2 id=floor(uv*6.),p=fract(uv*6.);
  if(id.x<1.||id.x>4.||id.y==3.){
   // Smooth blue insets; the serpent pattern is pigment, not embossing.
   float d=min(min(p.x,1.-p.x),min(p.y,1.-p.y));
   return .48+.10*(1.-smoothstep(.020,.030,d));
  }
  vec3 shape=stone_structure(uv);
  float bevel=smoothstep(.013,.045,shape.x);
  return .30+bevel*(.35+.018*clamp(shape.y+shape.z,-1.,1.));
 }
 if(item==2){
  vec2 q=vec2(fract(uv.x*3.)-.5,(uv.y-.5)*.75);
  float dome=sqrt(max(0.,1.-dot(q,q)/(.086*.086)));
  return .48+.20*dome*stud_mask(uv);
 }
 if(item==3){
  vec2 p=vec2(fract(uv.x*2.),uv.y);
  float x=fract(p.x*3.);
  float planks=smoothstep(.008,.024,min(x,1.-x));
  float h=.40+.16*planks;
  h=mix(h,.70,raised_frame(p,.066));
  return mix(h,.81,wall_fitting(p));
 }
 if(item==4){
  vec2 p=vec2(fract(uv.x*6.)-.5,(uv.y-.40)*1.5);
  float r=length(p);
  float disk=1.-smoothstep(.28,.305,r);
  float h=.35+.33*disk;
  h-=.055*stroke(spiral_distance(p*1.55),.016)*disk;
  return h+.035*stroke(uv.y-.87,.012);
 }
 if(item==5)return roof_height(uv);
 if(item==6){
  float h=roof_height(vec2(uv.x,uv.y*.25));
  h=mix(h,.36,smoothstep(.915,.925,uv.y));
  return h+.045*stroke(uv.y-.945,.012);
 }
 if(item==7){
  vec2 p=uv*vec2(3,4);p.x+=mod(floor(p.y),2.)*.5;
  vec2 f=fract(p),d=min(f,1.-f);
  float h=.32+.32*smoothstep(.009,.031,min(d.x,d.y));
  float side=min(uv.x,1.-uv.x);
  return mix(h,.66,1.-smoothstep(.037,.043,side));
 }
 if(item==8){
  vec2 p=vec2(fract(uv.x*4.),uv.y);
  float strap=rect(p,vec2(.5),vec2(.065,.39));
  return .48+.16*strap+.035*max(stroke(uv.y-.15,.016),stroke(uv.y-.85,.016));
 }
 vec2 p=vec2(fract(uv.x*2.),uv.y),f=fract(p*vec2(3,4));
 vec2 d=min(f,1.-f);
 float lattice=1.-smoothstep(.023,.035,min(d.x,d.y));
 float h=mix(.35,.66,lattice);
 h=mix(h,.73,raised_frame(p,.046));
 return mix(h,.82,facade_fitting(p));
}
vec2 design_response(vec2 uv){
 if(item==1){
  vec2 id=floor(uv*6.),p=fract(uv*6.);
  if(id.x<1.||id.x>4.||id.y==3.)return vec2(mix(.27,.40,raised_frame(p,.026)),0.);
  return vec2(.79,0.);
 }
 if(item==2){float stud=stud_mask(uv);return vec2(mix(.39,.29,stud),stud);}
 if(item==3){
  vec2 p=vec2(fract(uv.x*2.),uv.y);float metal=wall_fitting(p);
  return vec2(mix(mix(.64,.42,raised_frame(p,.066)),.31,metal),metal);
 }
 if(item==4)return vec2(.62,0.);
 if(item==5||item==6)return vec2(.52,0.);
 if(item==7)return vec2(mix(.75,.41,1.-smoothstep(.037,.043,min(uv.x,1.-uv.x))),0.);
 if(item==8){
  vec2 p=vec2(fract(uv.x*4.),uv.y);float metal=rect(p,vec2(.5),vec2(.065,.39));
  // The red decoration on each brass strap remains dielectric paint.
  metal*=1.-stroke(spiral_distance((p-.5)*vec2(7.0,1.5)),.016);
  return vec2(mix(.40,.31,metal),metal);
 }
 vec2 p=vec2(fract(uv.x*2.),uv.y),f=fract(p*vec2(3,4));
 vec2 d=min(f,1.-f);float lattice=1.-smoothstep(.023,.035,min(d.x,d.y));
 float metal=facade_fitting(p);
 return vec2(mix(mix(.88,.55,max(lattice,raised_frame(p,.046))),.31,metal),metal);
}
vec2 response_uv(vec2 uv){
 uv.x=fract(uv.x);
 if(item==1||item==5||item==7)uv.y=fract(uv.y);
 else uv.y=clamp(uv.y,texel.y*.5,1.-texel.y*.5);
 return uv;
}
void fragment(){
 vec2 uv=response_uv(UV);
 vec3 value=vec3(design_height(uv));
 if(response_pass==1){
  float dx=(design_height(response_uv(UV+vec2(texel.x,0)))-design_height(response_uv(UV-vec2(texel.x,0))))*height_range/(2.*texel.x*physical_repeat.x);
  float dy=(design_height(response_uv(UV+vec2(0,texel.y)))-design_height(response_uv(UV-vec2(0,texel.y))))*height_range/(2.*texel.y*physical_repeat.y);
  // OpenGL tangent Y points up while image V points down.
  value=normalize(vec3(-dx,dy,1.))*.5+.5;
 }else if(response_pass==2)value=vec3(design_response(uv),0.);
 COLOR=vec4(value,1.);
}
