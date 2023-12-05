with Ada.Text_IO; use Ada.Text_IO;

package body My_Min_Ada is

   --  Override for our use
   procedure Min_Application_Handler (
      ID             : Min_Ada.App_ID;
      Payload        : Min_Ada.Min_Payload;
      Payload_Length : Min_Ada.Byte
   ) is
   begin
      Put_Line ("Hello from the overridden Min_Application_Handler");
      Put_Line ("ID:" & ID'Image);
      Put_Line ("Payload (1):" & Payload (1)'Image);
      Put_Line ("Payload_Length:" & Payload_Length'Image);
   end Min_Application_Handler;

   procedure Tx_Byte (
      Data : Min_Ada.Byte
   ) is
   begin
      Put_Line ("Hello from the overridden Tx_Byte");
      Put_Line ("Data:" & Data'Image);
   end Tx_Byte;

   --  Overrides Min_Application_Handler
   procedure Override_Min_Application_Handler
   is
   begin
      Min_Ada.Set_Min_Application_Handler_Callback (
         Callback => Min_Application_Handler'Access
      );
   end Override_Min_Application_Handler;

   --  Overrides Tx_Byte
   procedure Override_Tx_Byte
   is
   begin
      Min_Ada.Set_Tx_Byte_Callback (
         Callback => Tx_Byte'Access
      );
   end Override_Tx_Byte;
end My_Min_Ada;
