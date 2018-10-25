import java.awt.Image;
import java.awt.Graphics2D;
import java.awt.geom.AffineTransform;
import java.awt.image.AffineTransformOp;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.io.OutputStream;
import java.io.FileOutputStream;
import javax.swing.ImageIcon;
import com.sun.image.codec.jpeg.JPEGCodec;
import com.sun.image.codec.jpeg.JPEGImageEncoder;

class NewHeight {
    public static void main(String[] args) 
    {
      if (args.length < 1)
      {
        System.out.println ("USAGE: java NewHeight infilename outfilename height");
        System.exit(1);
      }  
      createNewHeight(args[0], args[1], Integer.parseInt(args[2]));
    }

    /**
     * Reads an image in a file and creates a new image in another file.
     * @param orig The name of image file.
     * @param thumb The name of new file.  Will be created if necessary.
     * @param maxDim The height of the new file will be maxDim pixels.
     */
    public static void createNewHeight(String orig, String thumb, int maxDim) {
        try {
            // Get the image from a file.
            Image inImage = new ImageIcon(orig).getImage();
            
            // Determine the scale.
            double scale = (double)maxDim/(double)inImage.getHeight(null);
            
            // Determine size of new image. 
            int scaledW = (int)(scale*inImage.getWidth(null));
            int scaledH = (int)(scale*inImage.getHeight(null));

            // Create an image buffer in which to paint on.
            BufferedImage outImage = new BufferedImage(scaledW, scaledH,
                BufferedImage.TYPE_INT_RGB);
                
            
            // Set the scale.
            AffineTransform tx = new AffineTransform();

            // If the image is smaller than the desired image size,
            // don't bother scaling.
            if (scale < 1.0d) {
                tx.scale(scale, scale);
            }
            
            // Paint image.
            Graphics2D g2d = outImage.createGraphics();
            g2d.drawImage(inImage, tx, null);
            g2d.dispose();
            
            // JPEG-encode the image and write to file.
            OutputStream os = new FileOutputStream(thumb);
            JPEGImageEncoder encoder = JPEGCodec.createJPEGEncoder(os);
            encoder.encode(outImage);
            os.close();
            
        } catch (IOException e) {
            e.printStackTrace();
        }
        System.exit(0);
    }
    
}