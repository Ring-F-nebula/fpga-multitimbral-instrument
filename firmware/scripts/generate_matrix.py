"""Large read-only pressure guidance cells; no touch note hit targets."""
def generate_matrix(src, text, field):
    cells = []
    paint = ["if(page_q==6)begin",
             "surface_hit=y>=112&&y<548;surface_color=24'hf7f8fc;"]
    numbers = []
    regions = [dict(x=0, y=16, w=1024, h=96), dict(x=0, y=560, w=1024, h=32)]
    for i in range(16):
        col, row = i % 4, i // 4
        x, y, w, h = 16 + col * 252, 112 + row * 112, 236, 100
        cells.append(dict(index=i, label=i+1, row=row, column=col, x=x, y=y, w=w, h=h,
                          source=f'WAX A{i}', touch_triggers_note=False))
        nx, ny = x + 86, y + 12
        numbers.append(f"if(page_q==6&&x>={nx}&&x<{nx+64}&&y>={ny}&&y<{ny+56})begin number_visible=1;matrix_number=1;slot=6'd{32+i};digit_count=2;decimal_point=0;origin_x=11'd{nx};origin_y=10'd{ny};end")
        # The existing digit ROM is scaled 2x for the large cell number. Only
        # the small Ax label uses extra text tiles, preserving BSRAM capacity.
        text(6, x + 104 - (3 if i >= 10 else 0), y + 80, f'A{i}', 12)
        regions.append(dict(x=96+256*col, y=y+80, w=64, h=16))
        paint += [f"if(x>={x}&&x<{x+w}&&y>={y}&&y<{y+h})begin",
                  "surface_color=24'hffffff;matrix_edge=24'he0e5ef;",
                  f"if(running_q&&!info_q[81]&&cue_q[{i}])begin surface_color=24'hfff0c2;matrix_edge=24'he9b34a;end",
                  f"if(fsr_keys_q[{i}])begin surface_color=24'hdce9fd;matrix_edge=24'h7095d7;",
                  f"if(running_q&&!info_q[81])begin surface_color=cue_q[{i}]?24'he0f1e7:24'hf9dede;matrix_edge=cue_q[{i}]?24'h4c9e7a:24'hd88083;end end",
                  f"if(running_q&&!info_q[81]&&game_keys_q[{i}]&&!fsr_keys_q[{i}])begin",
                  f"if(feedback_q==4)matrix_edge=24'hd88083;else if(cue_q[{i}]&&(feedback_q==1||feedback_q==2))matrix_edge=24'h4c9e7a;end",
                  f"if(x<{x+4}||x>={x+w-4}||y<{y+4}||y>={y+h-4})surface_color=matrix_edge;",
                  "end"]
    paint.append('end')
    (src/'pressure_matrix_paint.vh').write_text('\n'.join(paint)+'\n', encoding='utf-8')
    (src/'pressure_matrix_numbers.vh').write_text('\n'.join(numbers)+'\n', encoding='utf-8')
    return dict(page=6, full_screen=True, order='row-major A0 upper-left through A15 lower-right',
                cells=cells, static_map_regions=regions, cell_number_scale=2,
                instruction='Press the physical pressure pad; touching a display cell never produces a note or score')
