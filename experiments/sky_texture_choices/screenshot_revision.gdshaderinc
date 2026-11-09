// Phase 1 screenshot revision. Uses the v3 slab and blade designs unchanged.
vec3 blue_panel_run(vec2 uv){
 vec3 c=keyed_stone(uv);
 float across=abs(uv.x-.52);
 float channel=1.0-smoothstep(.133,.136,across);
 c=mix(c,vec3(.36,.45,.29),channel);
 c=mix(c,PALE-.025,line(across-.143,.006));
 float inner=1.0-smoothstep(.112,.115,across);
 vec2 p=vec2((uv.x-.407)/.226,uv.y*4.0);
 float row=floor(p.y),seed=hash(vec2(3.0,row));
 vec3 blue=face(p*2.0,mix(vec3(.22,.41,.50),vec3(.34,.56,.63),seed),seed);
 // Angular translucent-looking tile segmentation, without reflected scenery,
 // highlights, painted light, emission, or actual transparency at this phase.
 vec2 local=fract(p);
 float key=.48+.13*step(.27,local.y)-.13*step(.66,local.y);
 float joint=line(local.x-key,.008);
 joint=max(joint,line(local.y-.27,.007)*box(local,vec2(.545,.27),vec2(.065,.03)));
 joint=max(joint,line(local.y-.66,.007)*box(local,vec2(.545,.66),vec2(.065,.03)));
 blue=mix(blue,vec3(.38,.68,.70),joint*.65);
 blue=mix(blue,vec3(.32,.44,.32),line(local.y,.018)+line(local.y-1.0,.018));
 blue=mix(blue,vec3(.48,.65,.61),line(local.y-.032,.005));
 return mix(c,blue,inner);
}
float lawn_region(vec2 uv){
 // Replace selected whole paving modules with turf, as in the screenshot.
 // 20 of 64 structural cells: roughly 31% grass and 69% stone.
 float id=block_id(floor(uv*8.0));
 return (id==3.0||id==6.0||id==8.0)?1.0:0.0;
}
vec3 garden_paving(vec2 uv){
 float lawn=lawn_region(uv);
 vec3 c=keyed_stone(uv);
 vec3 turf=grass(uv);
 // Keep the stone/grass boundary readable; no terrain or collision relief.
 return mix(c,turf,lawn);
}
void fragment(){
 vec3 c=item==1?blue_panel_run(UV):garden_paving(UV);
 COLOR=vec4(c,1.0);
}
