with Min_Ada;
with GNAT.Serial_Communications;
with Ada.Streams;

procedure Run is
   Context : Min_Ada.Min_Context;

   --  For sending frame
   Payload : Min_Ada.Min_Payload;

   --  For serial port
   Port : GNAT.Serial_Communications.Serial_Port;
   Buffer : Ada.Streams.Stream_Element_Array (1 .. 1);
   Offset : Ada.Streams.Stream_Element_Offset := 1;
begin

   --  Init the context
   Min_Ada.Min_Init_Context (Context);

   --  Create the payload
   Payload (1) := 2;
   Payload (2) := 3;

   --  Open the serial port (virtual serial port)
   --  Run socat -d -d pty,raw,echo=0 pty,raw,echo=0
   GNAT.Serial_Communications.Open (
      Port => Port,
      Name => "/dev/pts/2"
   );
   GNAT.Serial_Communications.Set (
      Port => Port,
      Rate => GNAT.Serial_Communications.B115200
   );

   --  Send this short payload
   Min_Ada.Send_Frame (
      Context => Context,
      ID => 5,
      Payload => Payload,
      Payload_Length => 2
   );

   --  Just receive whatever is on the serial port
   while True loop
      GNAT.Serial_Communications.Read (Port, Buffer, Offset);
      Min_Ada.Rx_Bytes (Context, Min_Ada.Byte'Val (Buffer (1)));
   end loop;
end Run;
