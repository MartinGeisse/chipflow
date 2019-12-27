
/**
 * Decoded segment numbering:
 *
 * 		 0000
 * 		1    2
 * 		1    2
 * 		 3333
 * 		4    5
 * 		4    5
 * 		 6666
 *
 * Decoding table:
 * Value / Segment	0	1	2	3	4	5	6
 * 0				x	x	x	.	x	x	x
 * 1				.	.	x	.	.	x	.
 * 2				x	.	x	x	x	.	x
 * 3				x	.	x	x	.	x	x
 * 4				.	x	x	x	.	x	.
 * 5				x	x	.	x	.	x	x
 * 6				x	x	.	x	x	x	x
 * 7				x	.	x	.	.	x	.
 * 8				x	x	x	x	x	x	x
 * 9				x	x	x	x	.	x	x
 * A				x	x	x	x	x	x	.
 * b				.	x	.	x	x	x	x
 * C				x	x	.	.	x	.	x
 * d				.	.	x	x	x	x	x
 * E				x	x	.	x	x	.	x
 * F				x	x	.	x	x	.	.
 *
 *
 * Note: takes 38 cells in OSU lib.
 * A schematic from the net uses 29, but needs 3-NAND (should be available) and 3-AND (is not available).
 * OTOH, we have some OAI cells which that schematic does not use.
 */
module SevenSegmentDecoder(
	input[3:0] encoded,
	output reg[6:0] decoded
);
	always @(*) begin
		case (encoded)
			// note: decoded values use reverse bit order than the table above!
			4'd0: decoded = 7'b1110111;
			4'd1: decoded = 7'b0100100;
			4'd2: decoded = 7'b1011101;
			4'd3: decoded = 7'b1101101;
			4'd4: decoded = 7'b0101110;
			4'd5: decoded = 7'b1101011;
			4'd6: decoded = 7'b1111011;
			4'd7: decoded = 7'b0100101;
			4'd8: decoded = 7'b1111111;
			4'd9: decoded = 7'b1101111;
			4'd10: decoded = 7'b0111111;
			4'd11: decoded = 7'b1111010;
			4'd12: decoded = 7'b1010011;
			4'd13: decoded = 7'b1111100;
			4'd14: decoded = 7'b1011011;
			4'd15: decoded = 7'b0011011;
			default: decoded = 0;
		endcase
	end
endmodule
