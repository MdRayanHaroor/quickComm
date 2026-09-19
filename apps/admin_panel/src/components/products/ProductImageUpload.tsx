import { useCallback, useState } from 'react';
import { useDropzone } from 'react-dropzone';
import { FaCloudUploadAlt, FaStar, FaTimes, FaLink } from 'react-icons/fa';
import { toast } from 'react-hot-toast';
import api from '../../api';
import { supabase } from '../../supabaseClient';

interface Props {
  productId: number | null;
  images: string[];
  onChange: (images: string[]) => void;
}

const ProductImageUpload = ({ productId, images, onChange }: Props) => {
  const [uploading, setUploading] = useState(false);
  const [urlInput, setUrlInput] = useState('');

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

  const handleAddUrl = (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    const trimmed = urlInput.trim();
    if (!trimmed) return;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      toast.error('Please enter a valid HTTP/HTTPS image URL');
      return;
    }
    onChange([...images, trimmed]);
    setUrlInput('');
    toast.success('Image URL added');
  };

  const remove = async (url: string, idx: number) => {
    const isBlobStorage = url.includes('/product-images/') || url.includes('/storage/v1/object/public/');
    const confirmMessage = isBlobStorage
      ? 'Are you sure you want to remove this image? This will permanently delete it from Supabase blob storage.'
      : 'Are you sure you want to remove this image URL?';

    if (!window.confirm(confirmMessage)) return;

    if (isBlobStorage) {
      if (productId && !url.startsWith('blob:')) {
        try {
          await api.delete(`/upload/product/${productId}/image`, { params: { image_url: url } });
          toast.success('Image deleted from storage');
        } catch (err: any) {
          console.error('Failed to delete image via API, trying direct storage remove:', err);
          try {
            const pathPart = url.split('/product-images/')[1]?.split('?')[0];
            if (pathPart) {
              await supabase.storage.from('product-images').remove([pathPart]);
              toast.success('Image deleted from storage');
            }
          } catch (_) {}
        }
      } else {
        // Blob url uploaded before saving
        try {
          const pathPart = url.split('/product-images/')[1]?.split('?')[0];
          if (pathPart) {
            await supabase.storage.from('product-images').remove([pathPart]);
            toast.success('Image deleted from storage');
          }
        } catch (_) {}
      }
    } else {
      toast.success('Image removed');
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

      {/* Add via direct URL */}
      <div style={{
        display: 'flex',
        gap: 8,
        alignItems: 'center',
        background: 'var(--surface-color, #f9fafb)',
        padding: '8px 12px',
        borderRadius: 10,
        border: '1px solid var(--border-color)'
      }}>
        <FaLink style={{ color: 'var(--text-muted)', fontSize: 14 }} />
        <input
          type="url"
          placeholder="Or paste an image web URL (https://...)"
          value={urlInput}
          onChange={e => setUrlInput(e.target.value)}
          onKeyDown={e => {
            if (e.key === 'Enter') {
              e.preventDefault();
              handleAddUrl();
            }
          }}
          style={{
            flex: 1,
            border: 'none',
            background: 'transparent',
            fontSize: 13,
            color: 'var(--text-primary)',
            outline: 'none'
          }}
        />
        <button
          type="button"
          className="btn btn-secondary"
          onClick={() => handleAddUrl()}
          disabled={!urlInput.trim()}
          style={{ padding: '6px 14px', fontSize: 12, fontWeight: 700 }}
        >
          Add URL
        </button>
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
                <img
                  src={url}
                  alt={`Product image ${idx + 1}`}
                  onError={(e) => {
                    // Fallback for broken URLs
                    (e.target as HTMLImageElement).src =
                      'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="60" height="60" viewBox="0 0 24 24" fill="none" stroke="%23999" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="M21 15l-5-5L5 21"/></svg>';
                  }}
                />

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
