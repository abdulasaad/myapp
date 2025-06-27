#!/usr/bin/env python3
"""
Script to create a padded version of logo2.png for better app icon appearance.
This adds white/transparent padding around the logo so it fits better in the circular app icon.
"""

try:
    from PIL import Image, ImageDraw
    import os
    
    def create_padded_icon():
        # Load the original logo
        logo_path = "icons/logo2.png"
        if not os.path.exists(logo_path):
            print(f"Error: {logo_path} not found!")
            return
        
        original = Image.open(logo_path).convert("RGBA")
        
        # Create a new image with padding (30% smaller logo, centered)
        size = original.size[0]  # Assuming square image
        new_size = size
        logo_size = int(size * 0.7)  # Make logo 70% of original size
        
        # Create new transparent image
        padded = Image.new("RGBA", (new_size, new_size), (0, 0, 0, 0))
        
        # Resize the original logo to be smaller
        resized_logo = original.resize((logo_size, logo_size), Image.Resampling.LANCZOS)
        
        # Calculate position to center the smaller logo
        x = (new_size - logo_size) // 2
        y = (new_size - logo_size) // 2
        
        # Paste the resized logo onto the new image
        padded.paste(resized_logo, (x, y), resized_logo)
        
        # Save the padded version
        output_path = "icons/logo2_padded.png"
        padded.save(output_path, "PNG")
        print(f"Created padded icon: {output_path}")
        
        return output_path
    
    if __name__ == "__main__":
        create_padded_icon()
        
except ImportError:
    print("PIL (Pillow) not found. Please install it with: pip install Pillow")
    print("Alternatively, you can manually create a padded version of your logo.")