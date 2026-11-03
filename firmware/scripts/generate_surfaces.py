"""Shared piano geometry and chord-based six-string guitar surfaces."""
def generate_surfaces(src):
    piano=[]
    for bank in range(2):
        base=60+16*bank
        whites=[s for s in range(16) if (base+s)%12 not in (1,3,6,8,10)]
        edges=[128+i*880//len(whites) for i in range(len(whites)+1)]
        for i,s in enumerate(whites):
            piano.append(dict(instrument=0,bank=bank,slot=s,black=False,x=edges[i],y=404,w=edges[i+1]-edges[i],h=180))
        for s in range(16):
            if s in whites:continue
            boundary=edges[sum(w<s for w in whites)]
            left=max(128,boundary-32);right=min(1008,boundary+32)
            piano.append(dict(instrument=0,bank=bank,slot=s,black=True,x=left,y=404,w=right-left,h=112))
    guitar=[]
    # The analyzer is permanent above the strings. Keep the legacy layout bit
    # in metadata/signatures for protocol compatibility, but never hide it.
    for analysis in (1,):
        for row in range(6):
            guitar.append(dict(instrument=1,analysis=analysis,row=row,
                               x=144,y=428+24*row,w=848,h=24))
    chords=[]
    for analysis in (1,):
        for chord,label in enumerate(['空弦','C','G','Am','F','Dm','Em']):
            chords.append(dict(analysis=analysis,chord=chord,label=label,action=43+chord,
                               x=136+124*chord,y=376,w=116,h=40))
    def rect(r,x='px',y='py'):
        return f"{x}>={r['x']} && {x}<{r['x']+r['w']} && {y}>={r['y']} && {y}<{r['y']+r['h']}"
    def selected(r):
        return f"instrument_q=={r['instrument']}"+(f" && bank_q==1'd{r['bank']}" if r['bank'] is not None else '')
    def active(r):return f"info_q[(bank_q?16:0)+{r['slot']}]"
    hit=['function [7:0] instrument_note_at;','input [1:0] tone;input upper;input [2:0] chord;input analysis;input [10:0] px;input [9:0] py;','reg [7:0] note;begin instrument_note_at=0;note=255;']
    # White keys first; black keys overwrite, never OR with the covered white.
    for r in piano:
        c=f"tone=={r['instrument']}"+(f" && upper==1'd{r['bank']}" if r['bank'] is not None else '')
        hit.append(f"if({c} && {rect(r)})instrument_note_at=8'd{128+r['slot']};")
    for r in guitar:
        hit.append(f"if(tone==1 && {rect(r)})begin note=guitar_note(chord,3'd{r['row']});if(note!=255)instrument_note_at=8'd128+note-8'd40;end")
    for r in chords:
        hit.append(f"if(tone==1 && {rect(r)})instrument_note_at=8'd{r['action']};")
    hit+=['end endfunction']
    (src/'instrument_notes.vh').write_text('\n'.join(hit)+'\n',encoding='utf-8')
    paint=["surface_hit=page_q==0 && x>=128 && x<1008 && y<584 && ((instrument_q==0 && y>=404)||(instrument_q==1 && y>=376));",
           "surface_color=instrument_q==1?24'hf1e6d4:24'hcbd3df;"]
    numbers=[];inks=[]
    for r in piano:
        x,y,w,h=r['x'],r['y'],r['w'],r['h'];pressed=active(r)
        paint.append(f"if({selected(r)} && {rect(r,'x','y')})begin")
        if r['black']:
            paint.append(f"surface_color={pressed}?24'h497eaa:24'h293344;")
            paint.append(f"if(x=={x} || x=={x+w-1} || y>={y+h-4})surface_color={pressed}?24'h32668f:24'h182232;")
            paint.append(f"if(x>{x+3} && x<{x+w-4} && y>={y+4} && y<{y+7})surface_color={pressed}?24'h85bce4:24'h49566b;")
        else:
            paint.append(f"surface_color={pressed}?24'hc5def7:24'hffffff;")
            paint.append(f"if(x=={x} || x=={x+w-1} || y>={y+h-4})surface_color={pressed}?24'h4f8fc0:24'hcbd3df;")
        paint.append('end')
        nx=x+(w-32)//2;ny=472 if r['black'] else 546
        box=dict(x=nx,y=ny,w=32,h=28)
        numbers.append(f"if(page_q==0 && {selected(r)} && {rect(box,'x','y')})begin number_visible=1;slot=6'd{32+r['slot']};digit_count=2;decimal_point=0;origin_x=11'd{nx};origin_y=10'd{ny};end")
        if r['black']:inks.append(f"if(page_q==0 && {selected(r)} && {rect(box,'x','y')})ink=24'hffffff;")
    paint.append("if(instrument_q==1)begin")
    paint.append("surface_color=24'hf1e6d4;")
    paint.append("if(x>=848)surface_color=24'hf5e5cf;")
    for r in guitar:
        row=r['row'];cy=r['y']+r['h']//2
        pressed=f"guitar_string_active[{row}]";muted=f"guitar_string_muted[{row}]"
        left=160
        paint.append(f"if({rect(r,'x','y')})begin")
        paint.append(f"if({pressed})surface_color=24'he4d6bd;")
        paint.append(f"if(x>={left} && x<984 && y>={cy} && y<{cy+1+row//2})surface_color={muted}?24'hc5b8a6:{pressed}?24'h397f9e:24'h94846c;")
        paint.append(f"if({pressed} && x>={left} && x<984 && y>={cy-2} && y<{cy+4})surface_color=24'h397f9e;")
        paint.append('end')
    for r in chords:
        paint.append(f"if({rect(r,'x','y')})surface_color=info_q[228:226]==3'd{r['chord']} ? 24'hd6e7ef : 24'hffffff;")
    paint.append('end')
    (src/'instrument_paint.vh').write_text('\n'.join(paint)+'\n',encoding='utf-8')
    (src/'instrument_numbers.vh').write_text('\n'.join(numbers)+'\n',encoding='utf-8')
    (src/'instrument_ink.vh').write_text('\n'.join(inks)+'\n',encoding='utf-8')
    return {'piano':piano,'guitar':guitar,'guitar_chords':chords,'guitar_analyzer_always_visible':True,'priority':'piano black keys overwrite white keys',
            'mapping':'piano retains editable MIDI mappings; guitar chord strings select fixed chromatic DDS slots MIDI40..71, preserving pitch in note-event recordings'}
