import { useCallback, useState } from 'react';
import { useDropzone } from 'react-dropzone';
import { FaCloudUploadAlt, FaStar, FaTimes } from 'react-icons/fa';
import { toast } from 'react-hot-toast';
import api from '../../api';

interface Props {
  productId: number | null;
  images: string[];
  onChange: (images: string[]) => void;
}

const ProductImageUpload = ({ productId, images, onChange }: Props) => {
  const [uploading, setUploading] = useState(false);

  const onDrop = useCallback(async (acceptedFiles: File[]) => {
    if (!productId) {
      // Product not yet saved — store as object URLs for preview
      // Real upload happens after product is created
      const previews = acceptedFiles.map(f => URL.createObjectURL(f));
      onChange([...images, ...previews]);
      toast('Images will upload after product is saved', { icon: 'ℹ️' });
      return;
    }

    setUploading(true);
    const uploaded: string[] = [];
    for (const file of acceptedFiles) {
      const formData = new FormData();
      formData.append('file', file);
      try {
        const res = await api.post(`/upload/product/${productId}/image`, formData, {
          headers: { 'Content-Type': 'multipart/form-data' },
        });
        uploaded.push(res.data.url);
      } catch {
        toast.error(`Failed to upload ${file.name}`);
      }
    }
    onChange([...images, ...uploaded]);
    toast.success(`${uploaded.length} image(s) uploaded`);
    setUploading(false);
  }, [productId, images, onChange]);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: { 'image/*': ['.jpg', '.jpeg', '.png', '.webp'] },
    maxSize: 5 * 1024 * 1024,
    multiple: true,
  });

  const remove = async (url: string, idx: number) => {
    if (productId && !url.startsWith('blob:')) {
      try {
        await api.delete(`/upload/product/${productId}/image`, { params: { image_url: url } });
      } catch {
        // Best effort
      }
    }
    onChange(images.filter((_, i) => i !== idx));
  };

  const makePrimary = (idx: number) => {
    const updated = [...images];
    const [moved] = updated.splice(idx, 1);
    onChange([moved, ...updated]);
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <div>
        <div style={{ fontWeight: 600, fontSize: 14 }}>Product Images</div>
        <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 2 }}>
          First image is the primary display image. Accepted: JPG, PNG, WebP (max 5MB each)
        </div>
      </div>

      {/* Dropzone */}
      <div
        {...getRootProps()}
        className={`dropzone ${isDragActive ? 'drag-active' : ''}`}
      >
        <input {...getInputProps()} />
        <div className="dropzone-icon">
          <FaCloudUploadAlt />
        </div>
        <div className="dropzone-text">
          {isDragActive
            ? 'Drop images here...'
            : uploading
              ? 'Uploading...'
              : 'Drag & drop images here, or click to browse'}
        </div>
        <div className="dropzone-hint">JPG, PNG, WebP · Max 5MB each · Multiple allowed</div>
      </div>

      {/* Image previews */}
      {images.length > 0 && (
        <div>
          <div style={{ fontSize: 12, color: 'var(--text-muted)', marginBottom: 8 }}>
            {images.length} image(s) — click ★ to set as primary
          </div>
          <div className="image-preview-grid">
            {images.map((url, idx) => (
              <div
                key={idx}
                className={`image-preview-item ${idx === 0 ? 'primary-img' : ''}`}
              >
                <img src={url} alt={`Product image ${idx + 1}`} />

                {/* Remove button */}
                <button
                  className="remove-btn"
                  onClick={() => remove(url, idx)}
                  type="button"
                  title="Remove image"
                >
                  <FaTimes />
                </button>

                {/* Primary indicator */}
                {idx === 0 ? (
                  <div className="primary-label">Primary</div>
                ) : (
                  <button
                    onClick={() => makePrimary(idx)}
                    type="button"
                    title="Set as primary"
                    style={{
                      position: 'absolute',
                      bottom: 2,
                      left: 2,
                      background: 'rgba(0,0,0,0.5)',
                      color: 'white',
                      border: 'none',
                      cursor: 'pointer',
                      fontSize: 10,
                      padding: '2px 5px',
                      borderRadius: 3,
                      opacity: 0,
                    }}
                    className="remove-btn"
                    onMouseEnter={e => (e.currentTarget.style.opacity = '1')}
                    onMouseLeave={e => (e.currentTarget.style.opacity = '0')}
                  >
                    <FaStar />
                  </button>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {!productId && images.length > 0 && (
        <div style={{
          background: 'var(--warning-light)',
          border: '1px solid var(--warning)',
          borderRadius: 'var(--radius-md)',
          padding: '10px 14px',
          fontSize: 12,
          color: '#92400E',
        }}>
          ⚠️ Images will be uploaded to storage after you save the product for the first time.
        </div>
      )}
    </div>
  );
};

export default ProductImageUpload;
