from AppKit import NSPasteboard

board = NSPasteboard.generalPasteboard()
if board.pasteboardItems():
    for item in board.pasteboardItems():
        for type_name in item.types():
            print(f"Type: {type_name}")
            if type_name == "public.utf8-plain-text":
                print(f"  String Value: {item.stringForType_(type_name)}")
            elif type_name == "public.file-url":
                print(f"  File URL: {item.stringForType_(type_name)}")
            else:
                # For other types, you might need to handle the data differently
                data = item.dataForType_(type_name)
                if data:
                    print(f"  Data (bytes): {len(data)} bytes")
                else:
                    print("  No data found for this type.")
else:
    print("No items found on the pasteboard.")
