In this example the Client creates a String data set of 0.1 MB containing just the char 1 and constantly sends it to the server. The Server "messsage" raw linked event does nothing with the data.
The UDF, as of now, does not consists of a packet buffer for repeated data sets to reduce the packet creation time, therefore this example shows the raw performance of the UDF.
