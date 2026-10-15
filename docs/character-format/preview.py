"""Static character-format v1 reference preview; not the package renderer.

Usage: python3 -I docs/character-format/preview.py INPUT OUTPUT [MOOD] [BAND]
Only documented static operations are painted. Unsupported operations fail.
"""
import copy
import html
import json
import math
from pathlib import Path
import re
import sys


def esc(v):
    return html.escape(str(v), quote=True)


def attrs(**kw):
    return ' '.join(f'{k.replace("_", "-")}="{esc(v)}"' for k,v in kw.items() if v is not None)


def element(tag, content='', **kw):
    return f'<{tag} {attrs(**kw)}>{content}</{tag}>'


def mul(a,b):
    x,y,z,w,u,v=a; X,Y,Z,W,U,V=b
    return [x*X+z*Y,y*X+w*Y,x*Z+z*W,y*Z+w*W,x*U+z*V+u,y*U+w*V+v]


def matrix(x=0,y=0,r=0,sx=1,sy=1):
    c,s=math.cos(r),math.sin(r)
    return [c*sx,s*sx,-s*sy,c*sy,x,y]


def transform(m):
    return 'matrix('+ ' '.join(f'{x:.8g}' for x in m)+')'


def shape(item):
    i=item; s=i['shape']; x,y=i.get('x',0),i.get('y',0)
    if s=='path': return 'path',{'d':i['d']}
    if s=='circle': return 'circle',dict(cx=x,cy=y,r=i['r'])
    if s=='ellipse': return 'ellipse',dict(cx=x,cy=y,rx=i['rx'],ry=i['ry'],transform=f'rotate({i.get("rotate",0)*180/math.pi} {x} {y})')
    if s=='rect':return 'rect',dict(x=x,y=y,width=i['w'],height=i['h'])
    if s=='round_rect':
        rr=i['r'];rr=[rr]*4 if not isinstance(rr,list) else rr
        tl,tr,br,bl=rr;w,h=i['w'],i['h']
        return 'path',{'d':f'M{x+tl} {y} L{x+w-tr} {y} Q{x+w} {y} {x+w} {y+tr} L{x+w} {y+h-br} Q{x+w} {y+h} {x+w-br} {y+h} L{x+bl} {y+h} Q{x} {y+h} {x} {y+h-bl} L{x} {y+tl} Q{x} {y} {x+tl} {y} Z'}
    if s=='polyline':return 'polyline',{'points':' '.join(f'{a},{b}' for a,b in i['points'])}
    if s=='arc':
        r,a,b=i['r'],i['start'],i['end'];span=(b-a)%(2*math.pi)
        if abs(b-a)>=2*math.pi-1e-9:return 'circle',dict(cx=x,cy=y,r=r)
        d=f'M{x+r*math.cos(a)} {y+r*math.sin(a)} A{r} {r} 0 {int(span>math.pi)} 1 {x+r*math.cos(b)} {y+r*math.sin(b)}'
        return 'path',dict(d=d+(' Z' if i.get('closed') else ''))
    if s in ('polygon','hexagon'):
        n=6 if s=='hexagon' else i['sides'];r=i['r'];a=i.get('rotate',0)
        p=[(x+r*math.sin(a+2*math.pi*k/n),y-r*math.cos(a+2*math.pi*k/n)) for k in range(n)]
        corner=i.get('corner',0)
        if not corner:return 'polygon',dict(points=' '.join(f'{a},{b}' for a,b in p))
        d=[]
        for k,(a,b) in enumerate(p):
            prev,nxt=p[k-1],p[(k+1)%n];v=[]
            for point in (prev,nxt):
                dist=math.dist((a,b),point);q=min(corner,dist/2)/dist;v.append((a+(point[0]-a)*q,b+(point[1]-b)*q))
            d.append(f'{"M" if not k else "L"}{v[0][0]} {v[0][1]} Q{a} {b} {v[1][0]} {v[1][1]}')
        return 'path',dict(d=' '.join(d)+' Z')
    raise ValueError('Unsupported static shape: '+s)


class Preview:
    def __init__(self,ch,mood,band):
        self.ch,self.band=ch,band;self.mood=ch['moods'][mood];self.defs=[];self.serial=0
        self.lod=ch.get('lod',{}).get(band,{})
        self.colours=copy.deepcopy(ch['colours'])
        for role,other in self.mood.get('recolour',{}).items():self.colours[role]=ch['colours'][other]
        self.channels={**ch.get('poses',{}).get(self.mood.get('pose'),{}),**self.mood.get('channels',{})}
        self.parts={p['id']:p for p in ch['parts']};self.states={};self.hidden=set(self.lod.get('hide',[]))
        h=ch['ground']['centre_height'];c=self.channels
        root=mul(mul(mul(mul(matrix(150,270-c.get('root.lift',0)),matrix(sx=c.get('root.scale_x',1)*c.get('root.flip',1),sy=c.get('root.scale_y',1))),matrix(0,-h)),matrix(r=c.get('root.rotate',0))),matrix(0,h))
        self.states['root']=(root,True,1,[])
        for id in self.parts:self.state(id)
        self.outline={**ch.get('outline',{}),**ch.get('outline',{}).get('lod',{}).get(band,{}),**self.lod.get('outline',{})}

    def uid(self):
        self.serial+=1;return 'p'+str(self.serial)

    def state(self,id):
        if id in self.states:return self.states[id]
        p=self.parts[id];m,visible,opacity,_=self.state(p.get('parent','root'));at=p.get('at',[0,0]);s=p.get('scale',1);s=s if isinstance(s,list) else [s,s];c=self.channels
        pivot=mul(m,matrix(at[0]+c.get(id+'.x',0),at[1]+c.get(id+'.y',0)))
        a,b,cc,d,_,_=m;det=a*d-b*cc;reflection=-1 if det<0 else 1
        if p.get('keep_upright'):
            first=math.hypot(a,b);second=abs(det)/first
            a,b,cc,d=first*(1 if p.get('no_flip') else reflection),0,0,second
        elif p.get('no_flip'):a,b=a*reflection,b*reflection
        m=mul([a,b,cc,d,pivot[4],pivot[5]],matrix(r=c.get(id+'.rotate',p.get('rotate',0)),sx=c.get(id+'.scale_x',s[0]),sy=c.get(id+'.scale_y',s[1])))
        visible=visible and c.get(id+'.visible',p.get('visible',True)) and id not in self.hidden and self.band in p.get('lod',['full','small','micro'])
        opacity*=c.get(id+'.opacity',p.get('opacity',1));variant=c.get(id+'.variant','default')
        switch=p.get('switch');variant=switch['variant'] if switch and c.get(switch['channel'],0)>switch['above'] else variant
        variant=self.lod.get('variants',{}).get(id,variant)
        items=p.get('items',[]) if variant=='default' else p['variants'][variant]
        self.states[id]=(m,visible,opacity,items);return self.states[id]

    def paint(self,value):
        if value is None:return 'none'
        if isinstance(value,str):return self.colours[value]
        p=self.ch['paints'][value['paint']];id=self.uid();stops=''.join(element('stop',offset=t,stop_color=self.colours[role],stop_opacity=a[0] if a else 1) for t,role,*a in p['stops'])
        if p['type']=='linear':
            a,b=p['from'],p['to'];self.defs.append(element('linearGradient',stops,id=id,gradientUnits='userSpaceOnUse',x1=a[0],y1=a[1],x2=b[0],y2=b[1]))
        else:
            a=p['centre'];f=p.get('focus',a);self.defs.append(element('radialGradient',stops,id=id,gradientUnits='userSpaceOnUse',cx=a[0],cy=a[1],fx=f[0],fy=f[1],r=p['r1'],fr=p.get('r0',0)))
        return 'url(#'+id+')'

    def raw(self,item,**style):
        tag,a=shape(item);return element(tag,**a,**style)

    def clip(self,ref):
        owner,id=ref.split('.',1);m,_,_,items=self.state(owner);i=next(i for i in items if i.get('id')==id);gid=self.uid()
        tag,geometry=shape(i);geometry['transform']=transform(m)+' '+geometry.get('transform','')
        self.defs.append(element('clipPath',element(tag,**geometry),id=gid,clipPathUnits='userSpaceOnUse'))
        return 'url(#'+gid+')'

    def item(self,i,outline=True):
        i=copy.deepcopy(i)
        if i['shape']=='ref':
            base=copy.deepcopy(self.ch['shapes'][i['use']]);base.update({k:v for k,v in i.items() if k not in ('shape','use','x','y','rotate','scale')});body=self.item(base,outline)
            return element('g',body,transform=transform(matrix(i.get('x',0),i.get('y',0),i.get('rotate',0),i.get('scale',1),i.get('scale',1))))
        st=dict(fill=self.paint(i.get('fill')),stroke=self.paint(i.get('stroke')),stroke_width=i.get('width',2.5),stroke_linecap=i.get('cap','round'),stroke_linejoin=i.get('join','round'),opacity=i.get('alpha',1))
        out=''
        if outline and i.get('outline'):
            for o in (self.outline.get('second') or {},self.outline):
                if o.get('width',0):out+=self.raw(i,fill='none',stroke=self.paint(o['colour']),stroke_width=o['width'],stroke_linejoin=self.outline.get('join','round'),stroke_linecap=self.outline.get('cap','round'),opacity=i.get('alpha',1))
        out+=self.raw(i,**st)
        if i.get('transform'):
            x,y,r=i['transform'];out=element('g',out,transform=transform(matrix(x,y,r)))
        return out

    def glow_filter(self, blur):
        id=self.uid()
        self.defs.append(element('filter',element('feGaussianBlur',stdDeviation=blur/2),id=id,x='-100%',y='-100%',width='300%',height='300%'))
        return 'url(#'+id+')'

    def face(self):
        f=self.ch.get('face')
        if not f:return ''
        m,visible,opacity,_=self.state(f['part'])
        if not visible:return ''
        flags=self.lod.get('face',{});kit=f['kit_definition'];ctrl={**kit.get('defaults',{}),**self.mood.get('face',{})}
        for key,val in self.channels.items():
            if key.startswith('face.'):ctrl[key[5:]]=val
        colours=self.colours;self.colours={**colours,**{key:colours[value] for key,value in f.get('colours',{}).items()}}
        at=f.get('at',[0,0]);scale=f.get('scale',1)*flags.get('scale',1);m=mul(m,matrix(*at,sx=scale,sy=scale));out='';ey=f.get('eyes',{});y=ey.get('y',-12);spacing=ey.get('spacing',30)
        blush=f.get('blush')
        if blush:
            a=blush.get('strong_alpha',.55) if ctrl.get('blush')=='strong' else blush.get('alpha',.45)*ctrl.get('blush',0)
            for sign in [-1,1]:out+=self.item(dict(shape='ellipse',x=sign*blush['x'],y=blush['y'],rx=blush['rx'],ry=blush['ry'],fill='blush_strong' if ctrl.get('blush')=='strong' else 'blush',alpha=a))
        for sign in [-1,1]:
            style=kit['eye_styles'][ctrl.get('eyes','open')];op=style['op'];body=''
            if op=='eye_ellipse':
                rx,ry=style['rx'],style['ry'];body+=self.raw(dict(shape='ellipse',rx=rx,ry=ry),fill=self.paint('eye_white'),stroke=self.paint(style.get('outline',{}).get('colour')) if style.get('outline') else 'none',stroke_width=style.get('outline',{}).get('width',0))
                pupil=style['pupil'];px,py=pupil.get('at',[0,0]);ran=pupil.get('look_range',[7,7]);px+=ctrl.get('look_x',0)*ran[0];py+=ctrl.get('look_y',0)*ran[1];r=pupil['r'];iris=ey.get('iris') if flags.get('iris',True) else None
                inner=''
                if iris:inner+=self.item(dict(shape='circle',x=px,y=py,r=r,fill=iris))
                inner+=self.item(dict(shape='circle',x=px,y=py,r=r*(.65 if iris else 1),fill='feature'))
                for g in pupil.get('glints',[{'at':[-.35,-.4],'r':.22}]):
                    gx,gy=g['at'];inner+=self.item(dict(shape='circle',x=px+gx*r,y=py+gy*r,r=g['r']*r,fill='shine'))
                u=max(style.get('lid',0),ctrl.get('lid',0),ctrl.get('blink',0));slant=style.get('slant',0)
                if u>0:
                    yy=-ry+u*2*ry;path=f'M{-1.2*rx} {-1.2*ry} L{1.2*rx} {-1.2*ry} L{1.2*rx} {yy+sign*slant} L{-1.2*rx} {yy-sign*slant} Z';inner+=self.item(dict(shape='path',d=path,fill='eyelid'))
                    edge=style.get('lid_edge',{})
                    if edge.get('width',0):inner+=self.item(dict(shape='polyline',points=[[-1.2*rx,yy-sign*slant],[1.2*rx,yy+sign*slant]],stroke=edge['colour'],width=edge['width']))
                id=self.uid();self.defs.append(element('clipPath',self.raw(dict(shape='ellipse',rx=rx-1,ry=ry-1)),id=id));body+=element('g',inner,clip_path='url(#'+id+')')
            elif op=='eye_arc':body+=self.item(dict(shape='arc',r=style['r'],start=style['start'],end=style['end'],y=style.get('y',0),stroke=style.get('stroke','feature'),width=style.get('width',5)))
            elif op=='eye_path':body+=self.item(dict(shape='path',d=style['d'],fill=style.get('fill','feature'),stroke=style.get('stroke'),width=style.get('width',2)))
            elif op=='eye_dots':
                for x,yy in style['centres']:body+=self.item(dict(shape='circle',x=x,y=yy,r=style['r'],fill=style.get('fill','feature')))
            else:raise ValueError('Unsupported face operation '+op)
            lashes=style.get('lashes')
            if lashes and ey.get('lashes',True) and flags.get('lashes',True):
                radii=lashes.get('radii',[style.get('rx',style.get('r')),style.get('ry',style.get('r'))]);a= lashes.get('at',[0,0])
                for ang in lashes['angles']:
                    x=a[0]+radii[0]*math.cos(ang);yy=a[1]+radii[1]*math.sin(ang);length=lashes.get('length',7)
                    body+=self.item(dict(shape='polyline',points=[[sign*x,yy],[sign*(x+length*math.cos(ang)),yy+length*math.sin(ang)]],stroke='feature',width=lashes.get('width',3)))
            if flags.get('brows',True) and not style.get('hide_brows',False):
                brow=kit['brow_styles'][ctrl.get('brows','none')]
                if brow.get('width',3.5)>0:body+=element('g',self.item(dict(shape='path',d=brow['d'],stroke=brow.get('stroke','feature'),width=brow.get('width',3.5))),transform=f'translate(0 {brow.get("y",-25)}) scale({sign} 1)')
            out+=element('g',body,transform=f'translate({sign*spacing} {y})')
        mouth=kit['mouth_styles'][ctrl.get('mouth','smile')];bx,by=mouth.get('box',[20,12]);by*=ctrl.get('open',1);body=''
        for item in mouth['items']:
            i=copy.deepcopy(item)
            if i['shape']=='path':
                n=0
                def repl(m):
                    nonlocal n
                    n+=1;return str(float(m[0])*(bx if n%2 else by))
                i['d']=re.sub(r'[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?',repl,i['d'])
            elif i['shape']=='polyline':i['points']=[[x*bx,y*by] for x,y in i['points']]
            elif i['shape']=='ellipse':
                for k,s in [('x',bx),('y',by),('rx',bx),('ry',by)]:i[k]=i.get(k,0)*s
            body+=self.item(i)
        out+=element('g',body,transform=f'translate(0 {f.get("mouth",{}).get("y",24)})');self.colours=colours
        if kit.get('glow') and self.lod.get('glow',self.band!='micro'):
            # SVG blur is an illustrative static approximation of Canvas shadowBlur.
            glow=kit['glow']
            out=element('g',out,filter=self.glow_filter(glow['blur']),opacity=glow.get('alpha',1))+out
        result=element('g',out,transform=transform(m),opacity=opacity)
        if f.get('clip'):result=element('g',result,clip_path=self.clip(f['clip']))
        return result

    def effects(self):
        results=[];face=self.ch.get('face')
        if not face:return results
        kit=face['kit_definition']
        for name,value in self.mood.get('effects',{}).items():
            if not value:continue
            mapping=self.ch.get('effects',{}).get(name)
            if not mapping:continue
            anchor=self.ch['anchors'][mapping['anchor']];m,visible,opacity,_=self.state(anchor['part'])
            if not visible or self.band not in anchor.get('lod',['full','small','micro']):continue
            x,y=anchor['at'];m=mul(m,matrix(x,y,anchor.get('rotate',0),anchor.get('scale',1),anchor.get('scale',1)))
            definition=kit['effects'][name];x,y=definition.get('at',[0,0]);alpha=1
            if definition['mode']=='progress':
                u=float(value);x+=definition.get('sway',2)*math.sin(u*definition.get('sway_rate',12));y+=u*definition.get('travel',26)
                if u>definition.get('fade_at',.9):alpha=(1-u)/(1-definition.get('fade_at',.9))
            elif definition['mode'] not in ('pulse','track'):raise ValueError('Unsupported static effect mode')
            items=definition['items'];body=''.join(self.item(i) for i in items)
            results.append((mapping.get('layer',0),element('g',body,transform=transform(mul(m,matrix(x,y))),opacity=opacity*alpha)))
        return results

    def render(self):
        drawings=[];shadow=self.ch['ground'].get('shadow')
        if shadow:drawings.append((-1e9,self.item(dict(shape='ellipse',x=150,y=270,rx=shadow['rx'],ry=shadow['ry'],fill=shadow['colour'],alpha=shadow.get('alpha',1)))))
        for n,(id,p) in enumerate(self.parts.items()):
            m,visible,opacity,items=self.state(id)
            if not visible:continue
            out=''
            for i in items:
                if self.band not in i.get('lod',['full','small','micro']) or id+'.'+i.get('id','') in self.hidden:continue
                painted=self.item(i)
                glow=p.get('glow')
                if glow and glow['item']==i.get('id') and self.lod.get('glow',self.band!='micro'):
                    emitted=copy.deepcopy(i);emitted.pop('clip',None);emitted.pop('outline',None)
                    if emitted.get('fill'):emitted['fill']=glow['colour']
                    if emitted.get('stroke'):emitted['stroke']=glow['colour']
                    painted=element('g',self.item(emitted),filter=self.glow_filter(glow['blur']),opacity=glow.get('alpha',1))+painted
                body=element('g',painted,transform=transform(m),opacity=opacity)
                if i.get('clip'):body=element('g',body,clip_path=self.clip(i['clip']))
                out+=body
            drawings.append((p.get('layer',0)+n*1e-7,out))
        f=self.ch.get('face')
        if f:drawings.append((f.get('layer',self.parts[f['part']].get('layer',0)+.5),self.face()))
        drawings.extend(self.effects())
        body=''.join(item for _,item in sorted(drawings,key=lambda v:v[0]))
        return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 300" role="img">'+element('title',esc(self.ch['name']+' static reference'))+element('defs',''.join(self.defs))+body+'</svg>'


def main():
    if len(sys.argv) not in (3,4,5):raise ValueError(__doc__)
    source,target=map(Path,sys.argv[1:3]);ch=json.loads(source.read_text());mood=sys.argv[3] if len(sys.argv)>3 else 'idle';band=sys.argv[4] if len(sys.argv)>4 else 'full'
    target.write_text(Preview(ch,mood,band).render(),encoding='utf-8');print(f'PASS: static SVG {ch["id"]} {mood} {band}; not runtime/animation evidence')


if __name__=='__main__':main()
