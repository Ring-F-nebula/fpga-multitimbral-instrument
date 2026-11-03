`timescale 1ns/1ps
module tb_uart_v2;
    reg clk=0; always #5 clk=~clk;
    reg rx=1;
    wire [15:0] keys,rc,edges;
    wire [7:0] last;
    wire [11:0] period;
    wire trained;
    wire [3:0] attack_sel,decay_sel,release_sel,volume;
    wire [7:0] sustain_level,param_count;
    uart_link dut(.clk(clk),.rx(rx),.pressed(keys),.rx_count(rc),.last_byte(last),
        .edges(edges),.bit_clocks(period),.trained(trained),.attack_sel(attack_sel),
        .decay_sel(decay_sel),.release_sel(release_sel),.volume(volume),
        .sustain_level(sustain_level),.param_count(param_count));
    task clocks(input integer n); repeat(n) @(negedge clk); endtask
    task send(input [7:0] b,input integer bit_time);
        @(negedge clk); rx=0; clocks(bit_time);
        for(integer j=0;j<8;j=j+1) begin rx=b[j]; clocks(bit_time); end
        rx=1; clocks(bit_time);
    endtask
    task configure(input [7:0] id,input [7:0] value,input [7:0] corruption);
        send(8'hf5,period); send(id,period); send(value,period);
        send(8'hf5^id^value^corruption,period); clocks(period*2);
    endtask
    task test_period(input integer bit_time);
        clocks(10000);
        repeat(32) send(8'h55,bit_time);
        clocks(10000);
        if(period<bit_time-1 || period>bit_time+1 || !trained)
            $fatal(1,"baud training got %d expected %d",period,bit_time);
        send(8'hf0,bit_time); send(8'h90,bit_time); send(8'h94,bit_time);
        clocks(bit_time*2); if(keys!=17) $fatal(1,"keys %h at period %d",keys,bit_time);
        send(8'h80,bit_time); clocks(bit_time*2); if(keys!=16) $fatal(1,"release");
        send(8'hf4,bit_time); clocks(bit_time*2); if(keys!=16) $fatal(1,"heartbeat");
        send(8'hf0,bit_time); clocks(bit_time*2); if(keys!=0) $fatal(1,"alloff");
    endtask
    wire tx;
    uart_status #(.PERIOD(1000)) status(clk,8'h08,16'h1234,8'h90,
        16'h0001,16'hffff,16'h0001,16'h0000,4'd8,12'd228,16'h5678,16'd500,9'd256,
        16'h0005,16'habcd,8'd255,16'h9876,
        4'd2,4'd5,4'd9,8'd160,4'd13,-9'sd123,8'd234,tx);
    reg [7:0] received[0:39];
    reg [7:0] check;
    integer f;
    task receive;
        reg [7:0] b;
        begin
            @(negedge tx); clocks(342);
            for(integer j=0;j<8;j=j+1) begin b[j]=tx; clocks(228); end
            if(tx!==1) $fatal(1,"status stop bit");
            received[f]=b;
        end
    endtask
    initial begin
        for(f=0;f<40;f=f+1) receive();
        if(received[0]!=8'ha5 || received[1]!=8'h5a || received[2]!=4) $fatal(1,"status header");
        check=0; for(integer j=2;j<39;j=j+1) check=check^received[j];
        if(check!=received[39]) $fatal(1,"status checksum");
        if(received[23]!=5 || received[24]!=0 || received[25]!=8'hcd || received[26]!=8'hab || received[27]!=255 || received[28]!=8'h76 || received[29]!=8'h98 || received[30]!=8'h41) $fatal(1,"v3 debug fields");
        if(received[4]!=8'h34 || received[5]!=8'h12 || received[7]!=1 || received[9]!=255 || received[16]!=228 || received[22]!=128) $fatal(1,"status fields");
        if(received[31]!=2 || received[32]!=5 || received[33]!=160 || received[34]!=9 || received[35]!=13 || received[36]!=8'h85 || received[37]!=8'hff || received[38]!=234) $fatal(1,"v4 parameter/signed bend fields");
    end
    initial begin
        clocks(10);
        if(attack_sel!=2 || decay_sel!=5 || sustain_level!=160 || release_sel!=5 || volume!=8 || param_count!=0) $fatal(1,"defaults");
        test_period(228); test_period(216); test_period(240);
        test_period(57); test_period(912);
        // Configuration payloads that resemble notes are not note commands.
        send(8'h91,period); clocks(period*2);
        configure(1,9,0); configure(2,0,0); configure(3,8'h91,0);
        configure(4,8,0); configure(5,15,0);
        if(attack_sel!=9 || decay_sel!=0 || sustain_level!=145 || release_sel!=8 || volume!=15 || param_count!=5 || keys!=2 || period!=912) $fatal(1,"valid configuration/held note/baud");
        configure(1,3,1); configure(1,10,0); configure(2,255,0);
        configure(4,10,0); configure(5,16,0); configure(0,10,0);
        if(attack_sel!=9 || decay_sel!=0 || release_sel!=8 || volume!=15 || param_count!=5 || keys!=2) $fatal(1,"invalid configuration changed state");
        configure(1,0,0); configure(2,9,0); configure(3,0,0);
        configure(4,0,0); configure(5,0,0); configure(3,255,0);
        if(attack_sel!=0 || decay_sel!=9 || sustain_level!=255 || release_sel!=0 || volume!=0 || param_count!=11) $fatal(1,"boundary values");
        // Every incomplete prefix must expire and allow the next note through.
        for(integer partial=1;partial<=3;partial=partial+1) begin
            send(8'hf5,period);
            if(partial>=2) send(8'h01,period);
            if(partial>=3) send(8'h02,period);
            clocks(270000);
            send(8'h92,period); clocks(period*2);
            if(keys!=6 || param_count!=11 || attack_sel!=0) $fatal(1,"partial packet recovery %d",partial);
            send(8'h82,period); clocks(period*2);
        end
        // A new training burst cancels an in-flight packet and clears notes.
        send(8'hf5,period); send(8'h01,period); clocks(50000);
        repeat(32) send(8'h55,228); clocks(10000);
        if(period!=228 || keys!=0 || param_count!=11) $fatal(1,"retraining/partial packet reset");
        configure(1,2,0);
        if(attack_sel!=2 || param_count!=12) $fatal(1,"configuration after retraining");
        // Isolated 55-valued payloads must never retune or clear held notes.
        send(8'h95,period); clocks(10000);
        repeat(20) configure(3,8'h55,0);
        if(keys!=32 || period!=228 || sustain_level!=85 || param_count!=32) $fatal(1,"false baud retraining");
        clocks(10000);
        if(f!=40) $fatal(1,"status test incomplete");
        $display("PASS UART v4: five baud rates/reconnect; note on/off; atomic ADSR/volume writes; invalid CRC/id/range; all partial timeouts; 55 payload immunity; 40-byte status and signed bend");
        $finish;
    end
    initial begin #100000000; $fatal(1,"timeout"); end
endmodule
