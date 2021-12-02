#include <png.h>
#include <stdint.h>
#include <string.h>

// only supports RGBA with optional colormap

int readPngFileInfo(
	const char* filepath,
	uint32_t* width, uint32_t* height,
	uint32_t* colormap_entries
) {
	png_image img;
	memset(&img, 0, sizeof(img));
	img.version = PNG_IMAGE_VERSION;
	png_image_begin_read_from_file(&img, filepath);
	if (width) *width = img.width;
	if (height) *height = img.height;
	if (colormap_entries) *colormap_entries = (img.format & PNG_FORMAT_FLAG_COLORMAP) ? img.colormap_entries : 0;
	png_image_free(&img);
	if (img.warning_or_error & PNG_IMAGE_ERROR) return 1;
	return 0;
}

int readPngMemoryInfo(
	const uint8_t* mem, size_t len,
	uint32_t* width, uint32_t* height,
	uint32_t* colormap_entries
) {
	png_image img;
	memset(&img, 0, sizeof(img));
	img.version = PNG_IMAGE_VERSION;
	png_image_begin_read_from_memory(&img, mem, len);
	if (width) *width = img.width;
	if (height) *height = img.height;
	if (colormap_entries) *colormap_entries = (img.format & PNG_FORMAT_FLAG_COLORMAP) ? img.colormap_entries : 0;
	png_image_free(&img);
	if (img.warning_or_error & PNG_IMAGE_ERROR) return 1;
	return 0;
}

int readPngFile(
	const char* filepath,
	const uint8_t* pixels,
	const uint8_t* colormap
) {
	png_image img;
	memset(&img, 0, sizeof(img));
	img.version = PNG_IMAGE_VERSION;
	png_image_begin_read_from_file(&img, filepath);
	int stride;
	if (colormap) {
		img.format = PNG_FORMAT_RGBA_COLORMAP;
		stride = img.width;
	} else {
		img.format = PNG_FORMAT_RGBA;
		stride = 4 * img.width;
	}
	png_image_finish_read(&img, NULL, pixels, stride, colormap);
	png_image_free(&img);
	if (img.warning_or_error & PNG_IMAGE_ERROR) return 1;
	return 0;
}

int readPngMemory(
	const uint8_t* mem, size_t len,
	const uint8_t* pixels,
	const uint8_t* colormap
) {
	png_image img;
	memset(&img, 0, sizeof(img));
	img.version = PNG_IMAGE_VERSION;
	png_image_begin_read_from_memory(&img, mem, len);
	int stride;
	if (colormap) {
		img.format = PNG_FORMAT_RGBA_COLORMAP;
		stride = img.width;
	} else {
		img.format = PNG_FORMAT_RGBA;
		stride = 4 * img.width;
	}
	png_image_finish_read(&img, NULL, pixels, stride, colormap);
	png_image_free(&img);
	if (img.warning_or_error & PNG_IMAGE_ERROR) return 1;
	return 0;
}

int writePngFile(
	const char* filepath,
	uint32_t width, uint32_t height,
	const uint8_t* pixels,
	const uint8_t* colormap,
	uint32_t colormap_entries
) {
	png_image img;
	memset(&img, 0, sizeof(img));
	img.version = PNG_IMAGE_VERSION;
	img.width = width;
	img.height = height;
	img.format = PNG_FORMAT_RGBA;
	if (colormap) {
		img.format |= PNG_FORMAT_FLAG_COLORMAP;
		img.colormap_entries = colormap_entries;
	}
	int stride = colormap ? width : 4 * width;
	png_image_write_to_file(&img, filepath, 0, pixels, stride, colormap);
	png_image_free(&img);
	if (img.warning_or_error & PNG_IMAGE_ERROR) return 1;
	return 0;
}

int writePngMemory(
	const uint8_t* mem, size_t* len,
	uint32_t width, uint32_t height,
	const uint8_t* pixels,
	const uint8_t* colormap,
	uint32_t colormap_entries)
{
	png_image img;
	memset(&img, 0, sizeof(img));
	img.version = PNG_IMAGE_VERSION;
	img.width = width;
	img.height = height;
	img.format = PNG_FORMAT_RGBA;
	if (colormap) {
		img.format |= PNG_FORMAT_FLAG_COLORMAP;
		img.colormap_entries = colormap_entries;
	}
	int stride = colormap ? width : 4 * width;
	png_image_write_to_memory(&img, mem, len, 0, pixels, stride, colormap);
	png_image_free(&img);
	if (img.warning_or_error & PNG_IMAGE_ERROR) return 1;
	return 0;
}