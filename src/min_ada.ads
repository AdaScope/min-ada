with System.CRC32;

package Min_Ada is

   type Bit     is mod 2**1     with Size => 1;
   type UInt4   is mod 2**4     with Size => 4;
   type Byte    is mod 2**8     with Size => 8;
   type UInt32  is mod 2**32    with Size => 32;

   MAX_PAYLOAD : constant Byte := 255;

   HEADER_BYTE : constant Byte := 16#AA#;
   STUFF_BYTE  : constant Byte := 16#55#;
   EOF_BYTE    : constant Byte := 16#55#;

   type Frame_State is (
      SEARCHING_FOR_SOF,
      RECEIVING_ID_CONTROL,
      RECEIVING_SEQ,
      RECEIVING_LENGTH,
      RECEIVING_PAYLOAD,
      RECEIVING_CHECKSUM_4,
      RECEIVING_CHECKSUM_3,
      RECEIVING_CHECKSUM_2,
      RECEIVING_CHECKSUM_1,
      RECEIVING_EOF
   );

   type App_ID is mod 2**6
      with Size => 6;

   type Frame_Header is record
      Header_1  : Byte;
      Header_2  : Byte;
      Header_3  : Byte;
      ID        : App_ID;
      Reserved  : Bit;
      Transport : Bit;
   end record with Size => 32;
   pragma Pack (Frame_Header);

   type Min_Payload is array (1 .. MAX_PAYLOAD) of Byte;

   type CRC_Bytes is array (1 .. 4) of Byte;

   type Min_Context is record

      --  Payload received so far
      Rx_Frame_Payload_Buffer  : Min_Payload;

      --  Checksum received over the wire
      Rx_Frame_Checksum        : CRC_Bytes;

      --  Calculated checksum for receiving frame
      Rx_Checksum              : System.CRC32.CRC32;

      --  Calculated checksum for sending frame
      Tx_Checksum              : System.CRC32.CRC32;

      --  Countdown of header bytes to reset state
      Rx_Header_Bytes_Seen     : Byte;

      --  State of receiver
      Rx_Frame_State           : Frame_State;

      --  Length of payload received so far
      Rx_Frame_Payload_Bytes   : Byte;

      --  ID and control bit of frame being received
      Rx_Frame_ID_Control      : Byte;

      --  Sequence number of frame being received
      Rx_Frame_Seq             : Byte;

      --  Length of frame
      Rx_Frame_Length          : Byte;

      --  Control byte
      Rx_Control               : Byte;

      --  Count out the header bytes
      Tx_Header_Byte_Countdown : Byte;

      --  Number of the port associated with the context
      Port                     : Byte;
   end record;

   --  Type for overriding Min_Application_Handler
   type Min_Application_Handler_Access is access
      procedure (
         ID             : App_ID;
         Payload        : Min_Payload;
         Payload_Length : Byte
      );

   --  Type for overriding Tx_Byte
   type Tx_Byte_Access is access
      procedure (
         Data : Byte
      );

   procedure Send_Frame (
      Context        : in out Min_Context;
      ID             : App_ID;
      Payload        : Min_Payload;
      Payload_Length : Byte
   );

   procedure Rx_Bytes (
      Context : in out Min_Context;
      Data    : Byte
   );

   procedure Tx_Byte (
      Data : Byte
   );

   procedure Stuffed_Tx_Byte (
      Context : in out Min_Context;
      Data    : Byte;
      CRC     : Boolean
   );

   procedure Min_Init_Context (
      Context : in out Min_Context
   );

   procedure Valid_Frame_Received (
      Context : Min_Context
   );

   function MSB_Is_One (
      Data : Byte
   ) return Boolean;

   procedure Min_Application_Handler (
      ID             : App_ID;
      Payload        : Min_Payload;
      Payload_Length : Byte
   );

   procedure Set_Min_Application_Handler_Callback (
      Callback : Min_Application_Handler_Access
   );

   procedure Set_Tx_Byte_Callback (
      Callback : Tx_Byte_Access
   );

end Min_Ada;
