import com.sun.imageio.plugins.jpeg.JPEGImageWriter;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageTypeSpecifier;
import javax.imageio.metadata.IIOMetadata;
import javax.imageio.plugins.jpeg.JPEGImageWriteParam;
import javax.imageio.stream.ImageOutputStream;
import java.awt.*;
import java.awt.geom.AffineTransform;
import java.awt.image.BufferedImage;
import java.io.*;
import java.util.HashSet;
import java.util.Set;

import static java.lang.System.*;

class Thumbnail {
  public static void main(String[] args) {
    // must supply either:
    //  1 arg (filename)        --or--
    //  3 args (in, out, size)  --or--
    //  4 args (in, out, size, quality) --or--
    //  5 args (in, out, size, quality, panoramic)
    if (args.length != 1 && args.length != 3 && args.length != 4 && args.length != 5) {
      out.println("Thumbnail: resizes JPEG files\n");

      out.println("USAGE:");
      out.println("  java Thumbnail infilename outfilename maxdim [quality] [panoramic]\n\n");

      out.println("  infilename and outfilename are full filenames or relative to");
      out.println("  the current directory, and must include the correct extension.\n");

      out.println("  maxdim is the maximum dimension of the output file in pixels.\n");

      out.println("  Quality is an optional argument, and should be number in");
      out.println("  the range 0.0 to 1.0. The default value is 0.75.\n");

      out.println("  Panoramic is an optional argument, and must be either 0 or 1.");
      out.println("  When it is set to 0, then the maxdim will be honored absolutely.");
      out.println("  When it is set to 1, special panoramic handling is applied, which");
      out.println("  causes panoramic photos to be resized so that they have the same");
      out.println("  height as a 'standard' picture, but a wider-than-maxdim width.");
      out.println("  This will also work for 'vertical' panoramas.");
      out.println("  To specify panoramic on the command line, you must also specify");
      out.println("  a value for quality. Default is 0.");


      out.println("  You can also supply a single parameter, the name of a standard");
      out.println("  text file that contains multiple files to resize (this is much");
      out.println("  faster for doing multiple files). The format of the file is:\n");

      out.println("   MaxSize  (an integer indicating max dimension in pixels)");
      out.println("   Quality  (a decimal value from 0.00 to 1.00. 0.75 is decent)");
      out.println("   Panoramic (this is 1 if you want special panoramic handling, 0 otherwise)");
      out.println("   infilename::outfilename\n");

      out.println("   (as many file pairs as needed)\n");

      exit(1);
    }
    // if one argument, it should be a filename with the following format:
    // maxdim
    // quality
    // panoramic
    // list of infilename,outfilename
    if (args.length == 1) {
//      System.err.println ("Reading from " + args[0]);
      try {
        BufferedReader inputFile = new BufferedReader(new FileReader(args[0]));

        int maxDim = Integer.parseInt(inputFile.readLine());
        float quality = Float.parseFloat(inputFile.readLine());
        int doPanoramic = Integer.parseInt(inputFile.readLine());
        Set<String> files = new HashSet<>();

        String theLine;
        while (inputFile.ready()) {
          theLine = inputFile.readLine();
          files.add(theLine);
//          System.err.println(">> " + theLine);
        }

//        System.err.println ("\nThere are " + files.size() + " pictures to resize\n");

        String[] arrayOfLines = (String[]) files.toArray(new String[0]);
//        System.err.println ("size of array is  " + arrayOfLines.length);

        String[] inAndOutNames = new String[2];
        // now we have everything...
        for (String arrayOfLine : arrayOfLines) {
//          System.err.println (i + "==== " + arrayOfLines[i]);

          inAndOutNames = arrayOfLine.split("::");
          if (inAndOutNames[0].length() > 0) {
//            System.err.println ("<<" + inAndOutNames[0] + " => " + inAndOutNames [1]);
            // this is our little progress meter...
            out.print(".");
            createThumbnail(inAndOutNames[0], inAndOutNames[1], maxDim, quality, doPanoramic);
          }
        }

      } catch (FileNotFoundException fnfe) {
        out.println("Could not find file " + args[0]);
        exit(1);
      } catch (IOException ioe) {
        out.println("Input Error reading file " + args[0]);
        exit(1);
      } catch (Throwable t) {
        handleFinalThrowable(t);
      }
      exit(0);
    }

    //System.out.println ("resize " + args[0] + " to " + args[1] + " size " + args[2]);
    if (args.length == 3) {
      try {
        createThumbnail(args[0], args[1], Integer.parseInt(args[2]), 0.75f, 0);
      } catch (Throwable t) {
        handleFinalThrowable(t);
      }
    } else if (args.length == 4) {
      try {
        createThumbnail(args[0], args[1], Integer.parseInt(args[2]), Float.parseFloat(args[3]), 0);
      } catch (Throwable t) {
        handleFinalThrowable(t);
      }

    } else if (args.length == 5) {
      try {
        createThumbnail(args[0], args[1], Integer.parseInt(args[2]), Float.parseFloat(args[3]), Integer.parseInt(args[4]));
      } catch (Throwable t) {
        handleFinalThrowable(t);
      }

    }
  }

  /**
   * Reads an image in a file and creates a thumbnail in another file.
   *
   * @param originalName  The name of image file.
   * @param thumbnailName The name of thumbnail file.  Will be created if necessary.
   * @param maxDim        The width and height of the thumbnail must
   *                      be maxDim pixels or less.
   * @param quality       a float between 0.0 and 1.0 indicating the compression quality.
   * @param panoramic     This should be 0 for no special panoramic handling or 1 for
   *                      special panoramic handling.
   */
  private static void createThumbnail(String originalName, String thumbnailName, int maxDim, float quality, int panoramic) {
    int inWidth = 0;
    int inHeight = 0;
    int scaledW = 0;
    int scaledH = 0;

    try {
      // Get the image from a file.
//      System.err.println ("Input Image name '"+originalName+"'");
      BufferedImage inImage = ImageIO.read(new File(originalName));

      inWidth = inImage.getWidth(null);
      inHeight = inImage.getHeight(null);
//      System.err.println ("Input image is "+inWidth+" x "+inHeight+" pixels.");

      // Determine the scale. Most of the time, we just resize so that
      // the image is maxDim pixels wide (or high). We make the largest
      // dimension of the picture match the maxDim. But for images that have
      // an abnormal aspect ratio (which are probably panoramas) we want to
      // resize them so the SMALLER dimension of the picture is sized to
      // what a 'normal' picture's resized dimension would be.
      // Normal aspect ratio for a picture is 1.333
      // Picture 2048 x 1536 = normal landscape. If Maxdim = 600, resized to 600x450
      // Picture 1536 x 2048 = normal portrait resizes to 450 x 600
      // picture 10087 x 4000 = panorama, resize to 1135 x 450
      //

      double aspectRatio = 0.0;
      double scale = 0.0;

      // landscape orientation
      if (inWidth > inHeight) {
        aspectRatio = (double) inWidth / (double) inHeight;
//        System.err.println ("Aspect ratio of " + originalName + " is " + aspectRatio);

        // panoramic?
        if (aspectRatio > 1.5 && panoramic == 1) {
          scaledH = (int) (maxDim / 1.333);
          scale = (double) scaledH / (double) inHeight;
          scaledW = (int) (inWidth * scale);
        }
        // no, normal aspect ratio
        else {
          scale = (double) maxDim / (double) inWidth;
          // Determine size of new image. One of them
          // should equal maxDim.
          scaledW = (int) (scale * inWidth);
          scaledH = (int) (scale * inHeight);
        }
      }
      // portrait orientation
      else {
        aspectRatio = (double) inHeight / (double) inWidth;
//        System.err.println ("Aspect ratio of " + originalName + " is " + aspectRatio);

        // strange case - vertical 'panoramas'
        if (aspectRatio > 1.5 && panoramic == 1) {
          scaledW = (int) (maxDim / 1.333);
          scale = (double) scaledW / (double) inWidth;
          scaledH = (int) (inHeight * scale);
        } else {
          scale = (double) maxDim / (double) inHeight;
          // Determine size of new image. One of them
          // should equal maxDim.
          scaledW = (int) (scale * inWidth);
          scaledH = (int) (scale * inHeight);
        }
      }

      // if the input image is smaller than the desired output size,
      // we're basically jst doing an inefficient copy - make the new
      // image the same size.
      if (scaledW > inWidth && scaledH > inHeight) {
        scaledW = inWidth;
        scaledH = inHeight;
      }
//      System.err.println ("Output image is "+scaledW+" x "+scaledH+" pixels.");

      String infoFileName = thumbnailName.substring(0, thumbnailName.lastIndexOf(".")) + ".info";
//      System.err.println ("info filename is  "+infoFileName);

      try {
        BufferedWriter outputFile = new BufferedWriter(new FileWriter(infoFileName));
        outputFile.write("<!-- INFO:width -->");
        outputFile.newLine();
        outputFile.write("" + scaledW);
        outputFile.newLine();
        outputFile.write("<!-- INFO:height -->");
        outputFile.newLine();
        outputFile.write("" + scaledH);
        outputFile.newLine();
        outputFile.flush();
        outputFile.close();
      } catch (IOException e) {
        err.println("Could not write info file " + infoFileName);
        err.println(e.getMessage());
        e.printStackTrace();
      }

      try {
        // Create an image buffer in which to paint on.
        BufferedImage outImage = new BufferedImage(scaledW, scaledH, BufferedImage.TYPE_INT_RGB);

        // Set the scale.
        AffineTransform transform = new AffineTransform();

        // If the input image is smaller than the desired image size,
        // don't bother scaling.
        if (scale < 1.0d) {
          transform.scale(scale, scale);
        }

        // Paint image.
        Graphics2D g2d = outImage.createGraphics();
        g2d.drawImage(inImage, transform, null);
        g2d.dispose();

        // JPEG-encode the image and write to file.
        OutputStream fileOutputStream = new FileOutputStream(thumbnailName);

        // Image writer
        JPEGImageWriter imageWriter = (JPEGImageWriter) ImageIO.getImageWritersBySuffix("jpg").next();
        ImageOutputStream imageOutputStream = ImageIO.createImageOutputStream(fileOutputStream);
        imageWriter.setOutput(imageOutputStream);

        // Image metadata
        IIOMetadata imageMetaData = imageWriter.getDefaultImageMetadata(new ImageTypeSpecifier(outImage), null);

        JPEGImageWriteParam jpegParams = (JPEGImageWriteParam) imageWriter.getDefaultWriteParam();
        jpegParams.setCompressionMode(JPEGImageWriteParam.MODE_EXPLICIT);
        jpegParams.setCompressionQuality(quality);

        imageWriter.write(imageMetaData, new IIOImage(outImage, null, null), null);
        imageOutputStream.close();
        imageWriter.dispose();

        fileOutputStream.close();

      } catch (IllegalArgumentException iae) {
        err.println("Could not resize " + originalName + "from " + inWidth + "x" + inHeight + " to " + scaledW + "x" + scaledH);
        err.println(iae.getMessage());
      }

    } catch (Exception ex) {
      err.println("Could not resize " + originalName + "from " + inWidth + "x" + inHeight + " to " + scaledW + "x" + scaledH);
      err.println(ex.getMessage());
      ex.printStackTrace();
    }
  }

  private static void handleFinalThrowable(Throwable t) {
    out.println("Error creating thumbnail: " + t.getMessage());
    t.printStackTrace();
    exit(1);
  }

}
