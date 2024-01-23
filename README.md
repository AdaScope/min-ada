# min-ada
This is a repo that is used to implement the min protocol in Ada
See https://github.com/min-protocol/min for more info.

## How to use
To use the protocol, you have to override two procedures: Min_Application_Handler and Tx_Byte.

Make sure to call the two procedures Override_Min_Application_Handler and Override_Tx_Byte in your code.
This will that the default implementations get overriden by the new ones you will be defining.

### Min_Application_Handler
#### Your .ads file should be exactly like this:

with Min_Ada; use Min_Ada;

package My_Min_Ada is

   procedure Min_Application_Handler (
      ID             : Min_Ada.App_ID;
      Payload        : Min_Ada.Min_Payload;
      Payload_Length : Min_Ada.Byte
   );

   procedure Override_Min_Application_Handler;
end My_Min_Ada;

#### And your .abd file should look something like this:

with Uart;
with Globals;

package body My_Min_Ada is

   procedure Min_Application_Handler (
      ID             : Min_Ada.App_ID;
      Payload        : Min_Ada.Min_Payload;
      Payload_Length : Min_Ada.Byte
   ) is
   begin
      --  Your code goes here
   end Min_Application_Handler;

   --  Overrides Min_Application_Handler
   procedure Override_Min_Application_Handler
   is
   begin
      Min_Ada.Set_Min_Application_Handler_Callback (
         Callback => Min_Application_Handler'Access
      );
   end Override_Min_Application_Handler;
end My_Min_Ada;

### Tx_Byte
#### Your .ads file should be exactly like this:

with Min_Ada; use Min_Ada;

package My_Min_Ada is

   procedure Tx_Byte (
      Data : Min_Ada.Byte
   );

   procedure Override_Tx_Byte;
end My_Min_Ada;

#### And your .abd file should look something like this:

with STM32.USARTs; use STM32.USARTs;
with STM32.Device; use STM32.Device;
with Uart_For_Board;
with Beta_Types;

package body My_Min_Ada is

   procedure Tx_Byte (
      Data : Min_Ada.Byte
   ) is
   begin
      --  Your code goes here
   end Tx_Byte;

   --  Overrides Tx_Byte
   procedure Override_Tx_Byte
   is
   begin
      Min_Ada.Set_Tx_Byte_Callback (
         Callback => Tx_Byte'Access
      );
   end Override_Tx_Byte;

end My_Min_Ada;
