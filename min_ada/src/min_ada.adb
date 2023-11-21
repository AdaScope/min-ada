with Ada.Text_IO; use Ada.Text_IO;
with Interfaces;  use Interfaces;

--  For UI
with Globals;

--  For firmware
with STM32.USARTs; use STM32USARTs;
with STM32.Device; use STM32.Device;
with Uart_For_Board;
with Beta_Types;

package body Min_Ada is

   procedure Send_Frame (
      Context           : in out Min_Context;
      ID                : App_ID;
      Payload           : Min_Payload;
      Payload_Length    : Byte
   ) is
      Checksum          : Interfaces.Unsigned_32;
      Checksum_Bytes    : CRC_Bytes with Address => Checksum'Address;
      ID_Control        : Byte with Address => Header.ID'Address;
      Header            : Frame_Header :=
         (HEADER_BYTE, HEADER_BYTE, HEADER_BYTE, ID, 0, 0);
   begin
      Context.Tx_Header_Byte_Countdown := 2;
      System.CRC32.Initialize (Context.Tx_Checksum);

      Tx_Byte (Header.Header_1);
      Tx_Byte (Header.Header_2);
      Tx_Byte (Header.Header_3);

      --  Send App ID, reserved bit, transport bit (together as one byte)
      Stuffed_Tx_Byte (Context, ID_Control, True);

      Stuffed_Tx_Byte (Context, Payload_Length, True);

      for P in 1 .. Payload_Length loop
         Stuffed_Tx_Byte (Context, Payload (P), True);
      end loop;

      Checksum := System.CRC32.Get_Value (Context.Tx_Checksum);

      Stuffed_Tx_Byte (Context, Checksum_Bytes (4), False);
      Stuffed_Tx_Byte (Context, Checksum_Bytes (3), False);
      Stuffed_Tx_Byte (Context, Checksum_Bytes (2), False);
      Stuffed_Tx_Byte (Context, Checksum_Bytes (1), False);

      Tx_Byte (EOF_BYTE);
   end Send_Frame;

   procedure Rx_Bytes (
      Context   : in out Min_Context;
      Data      : Byte
   ) is
      Real_Checksum     : Interfaces.Unsigned_32;
      Frame_Checksum    : Interfaces.Unsigned_32 with Address =>
         Context.Rx_Frame_Checksum'Address;
   begin
      if Context.Rx_Header_Bytes_Seen = 2 then
         Context.Rx_Header_Bytes_Seen := 0;

         if Data = HEADER_BYTE then
            Context.Rx_Frame_State := RECEIVING_ID_CONTROL;
            return;

         elsif Data = STUFF_BYTE then
            --  Discard byte and carry on receiving the next character
            return;
         else
            --  Something has gone wrong. Give up on frame and look for header
            Context.Rx_Frame_State := SEARCHING_FOR_SOF;
            return;
         end if;
      end if;

      if Data = HEADER_BYTE then
         Context.Rx_Header_Bytes_Seen := Context.Rx_Header_Bytes_Seen + 1;
      else
         Context.Rx_Header_Bytes_Seen := 0;
      end if;

      case Context.Rx_Frame_State is
         when SEARCHING_FOR_SOF =>
            null;

         when RECEIVING_ID_CONTROL =>
            Context.Rx_Frame_ID_Control     := Data;
            Context.Rx_Frame_Payload_Bytes  := 0;
            System.CRC32.Initialize (Context.Rx_Checksum);
            System.CRC32.Update (Context.Rx_Checksum, Character'Val (Data));

            if MSB_Is_One (Data) then
               Context.Rx_Frame_State := SEARCHING_FOR_SOF;
            else
               Context.Rx_Frame_Seq     := 0;
               Context.Rx_Frame_State   := RECEIVING_LENGTH;
            end if;

         when RECEIVING_SEQ =>
            Context.Rx_Frame_Seq := Data;
            System.CRC32.Update (Context.Rx_Checksum, Character'Val (Data));
            Context.Rx_Frame_State := RECEIVING_LENGTH;

         when RECEIVING_LENGTH =>
            Context.Rx_Frame_Length := Data;
            Context.Rx_Control      := Data;
            System.CRC32.Update (Context.Rx_Checksum, Character'Val (Data));

            if Context.Rx_Frame_Length > 0 then
               Context.Rx_Frame_State := RECEIVING_PAYLOAD;
            else
               Context.Rx_Frame_State := RECEIVING_CHECKSUM_4;
            end if;

         when RECEIVING_PAYLOAD =>
            Context.Rx_Frame_Payload_Buffer
               (Context.Rx_Frame_Payload_Bytes + 1) := Data;
            Context.Rx_Frame_Payload_Bytes :=
               Context.Rx_Frame_Payload_Bytes + 1;
            System.CRC32.Update (Context.Rx_Checksum, Character'Val (Data));
            Context.Rx_Frame_Length :=
               Context.Rx_Frame_Length - 1;
            if Context.Rx_Frame_Length = 0 then
               Context.Rx_Frame_State := RECEIVING_CHECKSUM_4;
            end if;

         when RECEIVING_CHECKSUM_4 =>
            Context.Rx_Frame_Checksum (4)   := Data;
            Context.Rx_Frame_State          := RECEIVING_CHECKSUM_3;

         when RECEIVING_CHECKSUM_3 =>
            Context.Rx_Frame_Checksum (3)   := Data;
            Context.Rx_Frame_State          := RECEIVING_CHECKSUM_2;

         when RECEIVING_CHECKSUM_2 =>
            Context.Rx_Frame_Checksum (2)   := Data;
            Context.Rx_Frame_State          := RECEIVING_CHECKSUM_1;

         when RECEIVING_CHECKSUM_1 =>
            Context.Rx_Frame_Checksum (1)   := Data;

            Real_Checksum := System.CRC32.Get_Value (Context.Rx_Checksum);
            if Frame_Checksum /= Real_Checksum then
               --  Frame fails the checksum and is dropped
               Context.Rx_Frame_State := SEARCHING_FOR_SOF;
               Put_Line ("Frame dropped!");
            else
               Context.Rx_Frame_State := RECEIVING_EOF;
            end if;

         when RECEIVING_EOF =>
            if Data = EOF_BYTE then
               --  Frame received OK, pass up data to handler
               Valid_Frame_Received (Context);
            end if;
            --  Look for next frame
            Context.Rx_Frame_State := SEARCHING_FOR_SOF;
      end case;

   end Rx_Bytes;

   procedure Valid_Frame_Received (
      Context : Min_Context
   ) is
   begin
      Min_Application_Handler (
         ID      => App_ID (Context.Rx_Frame_ID_Control),
         Payload => Context.Rx_Frame_Payload_Buffer,
         Payload_Length => Context.Rx_Frame_Payload_Bytes
      );
   end Valid_Frame_Received;

   procedure Tx_Byte (
      Data : Byte
   ) is
   begin
      Uart_For_Board.Put_Blocking (
         USART_1,
         Beta_Types.UInt16 (Data)
      );
   end Tx_Byte;

   procedure Stuffed_Tx_Byte (
      Context   : in out Min_Context;
      Data      : Byte;
      CRC       : Boolean
   ) is
   begin
      Tx_Byte (Data);
      if CRC then
         System.CRC32.Update (Context.Tx_Checksum, Character'Val (Data));
      end if;

      if Data = HEADER_BYTE then
         Context.Tx_Header_Byte_Countdown :=
            Context.Tx_Header_Byte_Countdown - 1;

         if Context.Tx_Header_Byte_Countdown = 0 then
            Tx_Byte (STUFF_BYTE);
            Context.Tx_Header_Byte_Countdown := 2;
         end if;
      else
         Context.Tx_Header_Byte_Countdown := 2;
      end if;

   end Stuffed_Tx_Byte;

   procedure Min_Init_Context (
      Context : in out Min_Context
   ) is
   begin
      Context.Rx_Header_Bytes_Seen := 0;
      Context.Rx_Frame_State := SEARCHING_FOR_SOF;
   end Min_Init_Context;

   function MSB_Is_One (
      Data : Byte
   ) return Boolean is
      MSB : Interfaces.Unsigned_8;
   begin
      MSB := Interfaces.Shift_Right (
         Value  => Interfaces.Unsigned_8 (Data),
         Amount => 7
      );
      if MSB = 1 then
         return True;
      else
         return False;
      end if;
   end MSB_Is_One;

   procedure Min_Application_Handler (
      ID             : App_ID;
      Payload        : Min_Payload;
      Payload_Length : Byte
   ) is
      --  To store one reading (one number)
      Reading        : String (1 .. 4) := "0000";

      --  To keep track of the index in the reading
      Reading_Index  : Integer := 1;

      --  Current digit received in the payload
      Current_Digit  : Character;
   begin

      --  Check if fist frame to reset the buffers (this makes sure the
      --  data in the buffers is always contiguous
      if ID = 5 or else ID = 6 or else ID = 7 then
         Globals.Buffered_Data.Reset_Buffer (
            Channel => Integer'Value (ID'Image)
         );
      end if;

      --  Loop over all the data in the payload
      for I in 1 .. Integer'Val (Payload_Length) loop

         --  Transform the payload byte in a character
         Current_Digit := Character'Val (Payload (Byte (I)));

         --  Make sure Reading_Index in bounds
         if Reading_Index > 5 then
            Reading_Index  := 1;
         end if;

         --  If we read a line ending
         --  And reading is not empty
         if Current_Digit = ASCII.LF and then
            Reading_Index > 1
         then
            --  Save the current number in the data buffer
            Globals.Buffered_Data.Set_Data (
               Channel => Integer'Value (ID'Image),
               Data => Float'Value (Reading (1 .. Reading_Index - 1))
            );
            --  Reset the reading index
            Reading_Index := 1;

         --  If we do not read a line ending
         elsif Current_Digit /= ASCII.LF then
            --  Reading not full (we don't have 4 digits in our reading yet)
            if Reading_Index <= 4 then

               --  We save the current digit to
               --  the current index of our reading and increment the index
               Reading (Reading_Index) := Current_Digit;
            end if;

            --  Increment the reading index (even if index > 4)
            Reading_Index := Reading_Index + 1;
         end if;
      end loop;
   end Min_Application_Handler;

end Min_Ada;
