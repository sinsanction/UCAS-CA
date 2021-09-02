`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       36
    `define FS_TO_DS_BUS_WD 104
    `define DS_TO_ES_BUS_WD 211
    `define ES_TO_MS_BUS_WD 204
    `define MS_TO_WS_BUS_WD 161
    `define WS_TO_RF_BUS_WD 38

    `define ES_TO_DS_BUS_WD 41
    `define MS_TO_DS_BUS_WD 42
    `define WS_TO_DS_BUS_WD 39

    `define WS_TO_FS_EXBUS_WD 33
    `define WS_TO_DS_EXBUS_WD 2
    `define WS_TO_ES_EXBUS_WD 5
    `define WS_TO_MS_EXBUS_WD 1
    `define MS_TO_ES_EXBUS_WD 4

    `define FS_TO_TLB_BUS_WD 20
    `define TLB_TO_FS_BUS_WD 30
    `define ES_TO_TLB_BUS_WD 21
    `define TLB_TO_ES_BUS_WD 30
    `define WS_TO_TLB_BUS_WD 83
    `define TLB_TO_WS_BUS_WD 78
    `define CP0_TO_TLB_BUS_WD 82
    `define TLB_TO_CP0_BUS_WD 78

    `define CP0_INDEX           {5'd0, 3'd0}
    `define CP0_ENTRYLO0        {5'd2, 3'd0}
    `define CP0_ENTRYLO1        {5'd3, 3'd0}
    `define CP0_BADVADDR        {5'd8, 3'd0}
    `define CP0_COUNT           {5'd9, 3'd0}
    `define CP0_ENTRYHI         {5'd10, 3'd0}
    `define CP0_COMPARE         {5'd11, 3'd0}
    `define CP0_STATUS          {5'd12, 3'd0}
    `define CP0_CAUSE           {5'd13, 3'd0}
    `define CP0_EPC             {5'd14, 3'd0}
    `define CP0_CONFIG          {5'd16, 3'd0}
    `define CP0_CONFIG1         {5'd16, 3'd1}

`endif