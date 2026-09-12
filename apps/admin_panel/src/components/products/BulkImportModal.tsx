import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { FaFileDownload, FaFileUpload, FaCheckCircle, FaExclamationCircle, FaTimes, FaBoxes } from 'react-icons/fa';
import { toast } from 'react-hot-toast';
import api from '../../api';

interface ParsedProduct {
  name: string;
  category?: string;
  brand?: string;
  description?: string;
  unit?: string;
  mrp?: number;
  selling_price?: number;
  stock?: number;
  barcode?: string;
  image_url?: string;
  isValid: boolean;
  error?: string;
}

interface BulkImportModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

const TEMPLATE_CSV = `Name,Category,Brand,Description,Unit,MRP,Selling Price,Stock,Barcode,Image URL
Amul Taaza Toned Milk,Dairy,Amul,Pasteurised fresh toned milk pouch,500 ml,28,27,50,890126201001,
Fortune Sunlite Sunflower Oil,Pantry & Staples,Fortune,Refined sunflower cooking oil pouch,1 L,165,152,35,890600728001,
Tata Salt Vacuum Evaporated,Pantry & Staples,Tata,Iodised table cooking salt,1 kg,28,26,100,890400440001,
Lays Classic Salted Potato Chips,Snacks & Munchies,Lays,Crispy salted potato wafers,50 g,20,20,60,890149110001,`;

export const BulkImportModal: React.FC<BulkImportModalProps> = ({ isOpen, onClose, onSuccess }) => {
  const [file, setFile] = useState<File | null>(null);
  const [parsedRows, setParsedRows] = useState<ParsedProduct[]>([]);
  const [isDragging, setIsDragging] = useState(false);
  const [importing, setImporting] = useState(false);
  const [previewTab, setPreviewTab] = useState<'preview' | 'paste'>('preview');
  const [pastedText, setPastedText] = useState('');

  // Close on Escape
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && !importing) onClose();
    };
    if (isOpen) window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, importing, onClose]);

  if (!isOpen) return null;

  const downloadTemplate = () => {
    const blob = new Blob([TEMPLATE_CSV], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'quickcomm_product_import_template.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
    toast.success('Template downloaded. Open in Excel or Google Sheets to fill products.');
  };

  const parseCSVContent = (content: string) => {
    const lines = content.split(/\r?\n/).filter(line => line.trim().length > 0);
    if (lines.length < 2) {
      toast.error('CSV file contains no data rows');
      return;
    }

    // Split headers
    const headers = lines[0].split(',').map(h => h.trim().toLowerCase().replace(/['"]/g, ''));

    const nameIdx = headers.findIndex(h => h.includes('name'));
    const catIdx = headers.findIndex(h => h.includes('category'));
    const brandIdx = headers.findIndex(h => h.includes('brand'));
    const descIdx = headers.findIndex(h => h.includes('desc'));
    const unitIdx = headers.findIndex(h => h.includes('unit'));
    const mrpIdx = headers.findIndex(h => h.includes('mrp'));
    const spIdx = headers.findIndex(h => h.includes('selling') || h.includes('price'));
    const stockIdx = headers.findIndex(h => h.includes('stock') || h.includes('qty'));
    const barcodeIdx = headers.findIndex(h => h.includes('barcode'));
    const imgIdx = headers.findIndex(h => h.includes('image'));

    if (nameIdx === -1) {
      toast.error("CSV header must contain a 'Name' column");
      return;
    }

    // Parse CSV line handling potential quoted commas
    const parseLine = (line: string): string[] => {
      const row: string[] = [];
      let inQuotes = false;
      let token = '';
      for (let i = 0; i < line.length; i++) {
        const char = line[i];
        if (char === '"' || char === "'") {
          inQuotes = !inQuotes;
        } else if (char === ',' && !inQuotes) {
          row.push(token.trim());
          token = '';
        } else {
          token += char;
        }
      }
      row.push(token.trim());
      return row;
    };

    const parsed: ParsedProduct[] = [];

    for (let i = 1; i < lines.length; i++) {
      const cols = parseLine(lines[i]);
      const name = cols[nameIdx]?.replace(/['"]/g, '').trim();

      if (!name) continue;

      const mrp = mrpIdx !== -1 ? parseFloat(cols[mrpIdx]) || 0 : 0;
      const sp = spIdx !== -1 ? parseFloat(cols[spIdx]) || mrp : mrp;
      const stock = stockIdx !== -1 ? parseInt(cols[stockIdx], 10) || 0 : 0;

      let isValid = true;
      let error = '';

      if (sp > mrp && mrp > 0) {
        isValid = false;
        error = `Selling Price (₹${sp}) exceeds MRP (₹${mrp})`;
      }

      parsed.push({
        name,
        category: catIdx !== -1 ? cols[catIdx]?.replace(/['"]/g, '').trim() : undefined,
        brand: brandIdx !== -1 ? cols[brandIdx]?.replace(/['"]/g, '').trim() : undefined,
        description: descIdx !== -1 ? cols[descIdx]?.replace(/['"]/g, '').trim() : undefined,
        unit: unitIdx !== -1 ? cols[unitIdx]?.replace(/['"]/g, '').trim() || '1 unit' : '1 unit',
        mrp: mrp || sp,
        selling_price: sp,
        stock,
        barcode: barcodeIdx !== -1 ? cols[barcodeIdx]?.replace(/['"]/g, '').trim() : undefined,
        image_url: imgIdx !== -1 ? cols[imgIdx]?.replace(/['"]/g, '').trim() : undefined,
        isValid,
        error
      });
    }

    setParsedRows(parsed);
    if (parsed.length > 0) {
      toast.success(`Parsed ${parsed.length} product rows from file`);
    }
  };

  const handleFileChange = (selectedFile: File) => {
    setFile(selectedFile);
    const reader = new FileReader();
    reader.onload = (e) => {
      const text = e.target?.result as string;
      if (text) parseCSVContent(text);
    };
    reader.readAsText(selectedFile);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFileChange(e.dataTransfer.files[0]);
    }
  };

  const handleImportSubmit = async () => {
    if (parsedRows.length === 0) {
      toast.error('No valid products to import');
      return;
    }

    setImporting(true);
    try {
      const payload = {
        products: parsedRows.map(p => ({
          name: p.name,
          category: p.category,
          brand: p.brand,
          description: p.description,
          unit: p.unit,
          mrp: p.mrp,
          selling_price: p.selling_price,
          stock: p.stock,
          barcode: p.barcode,
          image_url: p.image_url
        })),
        store_id: 1
      };

      const res = await api.post('/products/bulk-import', payload);
      if (res.data?.success) {
        toast.success(`Successfully imported ${res.data.imported_count} products!`);
        onSuccess();
        onClose();
      } else {
        toast.error('Bulk import encountered issues');
      }
    } catch (e: any) {
      toast.error(e.response?.data?.detail || e.message || 'Bulk import failed');
    } finally {
      setImporting(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <motion.div
        className="modal-dialog"
        initial={{ scale: 0.95, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        exit={{ scale: 0.95, opacity: 0 }}
        onClick={e => e.stopPropagation()}
        style={{ maxWidth: 840, width: '90%', maxHeight: '90vh', display: 'flex', flexDirection: 'column' }}
      >
        {/* Header */}
        <div className="drawer-header" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <h2 style={{ margin: 0, fontSize: '1.25rem', display: 'flex', alignItems: 'center', gap: 8 }}>
              <FaBoxes color="var(--brand-primary)" /> Bulk Import Products
            </h2>
            <p style={{ margin: '4px 0 0', fontSize: 13, color: 'var(--text-muted)' }}>
              Quickly upload multiple products with variants, categories, brands, and stock using an Excel/CSV spreadsheet.
            </p>
          </div>
          <button onClick={onClose} className="btn btn-ghost" style={{ padding: 8 }} title="Close">
            <FaTimes />
          </button>
        </div>

        {/* Body */}
        <div style={{ padding: '20px 24px', flex: 1, overflowY: 'auto' }}>
          {/* Step 1: Download Template Banner */}
          <div style={{
            background: 'var(--bg-surface-elevated)',
            border: '1px solid var(--border)',
            borderRadius: 'var(--radius-md)',
            padding: '14px 18px',
            marginBottom: 20,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 16
          }}>
            <div>
              <strong style={{ fontSize: 14, color: 'var(--text-primary)', display: 'block' }}>
                Need the standard spreadsheet format?
              </strong>
              <span style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
                Download our blank template with sample supermarket columns (Name, Category, Brand, MRP, Selling Price, Stock, Barcode).
              </span>
            </div>
            <button
              onClick={downloadTemplate}
              className="btn btn-secondary"
              style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, flexShrink: 0 }}
            >
              <FaFileDownload /> Download Excel / CSV Template
            </button>
          </div>

          {/* Tab Selection */}
          <div style={{ display: 'flex', gap: 12, marginBottom: 16 }}>
            <button
              onClick={() => setPreviewTab('preview')}
              className={`btn ${previewTab === 'preview' ? 'btn-primary' : 'btn-ghost'}`}
              style={{ fontSize: 13 }}
            >
              Upload Spreadsheet File
            </button>
            <button
              onClick={() => setPreviewTab('paste')}
              className={`btn ${previewTab === 'paste' ? 'btn-primary' : 'btn-ghost'}`}
              style={{ fontSize: 13 }}
            >
              Paste CSV / Text
            </button>
          </div>

          {previewTab === 'preview' ? (
            /* Drag and Drop Zone */
            <div
              onDragOver={e => { e.preventDefault(); setIsDragging(true); }}
              onDragLeave={() => setIsDragging(false)}
              onDrop={handleDrop}
              style={{
                border: `2px dashed ${isDragging ? 'var(--brand-primary)' : 'var(--border)'}`,
                borderRadius: 'var(--radius-lg)',
                padding: '32px 20px',
                textAlign: 'center',
                background: isDragging ? 'var(--brand-light)' : 'var(--bg-input)',
                cursor: 'pointer',
                transition: 'all 0.2s ease',
                marginBottom: 20
              }}
              onClick={() => document.getElementById('bulk-file-input')?.click()}
            >
              <input
                id="bulk-file-input"
                type="file"
                accept=".csv,text/csv,text/plain"
                style={{ display: 'none' }}
                onChange={e => {
                  if (e.target.files?.[0]) handleFileChange(e.target.files[0]);
                }}
              />
              <FaFileUpload size={32} color={isDragging ? 'var(--brand-primary)' : 'var(--text-muted)'} style={{ marginBottom: 10 }} />
              <div style={{ fontWeight: 600, color: 'var(--text-primary)', fontSize: 14 }}>
                {file ? file.name : 'Click to select or drag and drop your completed CSV file here'}
              </div>
              <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 4 }}>
                Accepts .csv files exported from Microsoft Excel, Apple Numbers, or Google Sheets
              </div>
            </div>
          ) : (
            <div style={{ marginBottom: 20 }}>
              <textarea
                value={pastedText}
                onChange={e => setPastedText(e.target.value)}
                placeholder="Paste CSV rows here (including header line)..."
                rows={6}
                style={{ fontFamily: 'monospace', fontSize: 12, width: '100%' }}
              />
              <button
                onClick={() => parseCSVContent(pastedText)}
                className="btn btn-secondary"
                style={{ marginTop: 8, fontSize: 12 }}
                disabled={!pastedText.trim()}
              >
                Parse Pasted Rows
              </button>
            </div>
          )}

          {/* Parsed Preview Table */}
          {parsedRows.length > 0 && (
            <div>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
                <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--text-primary)' }}>
                  Preview: {parsedRows.length} Products Detected
                </span>
                <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                  Categories and brands not currently in the catalog will be automatically created.
                </span>
              </div>

              <div style={{
                maxHeight: 280,
                overflowY: 'auto',
                border: '1px solid var(--border)',
                borderRadius: 'var(--radius-md)',
                background: 'var(--bg-surface)'
              }}>
                <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
                  <thead>
                    <tr style={{ background: 'var(--bg-surface-elevated)', borderBottom: '1px solid var(--border)', textAlign: 'left' }}>
                      <th style={{ padding: '8px 12px' }}>Status</th>
                      <th style={{ padding: '8px 12px' }}>Product Name</th>
                      <th style={{ padding: '8px 12px' }}>Category</th>
                      <th style={{ padding: '8px 12px' }}>Brand</th>
                      <th style={{ padding: '8px 12px' }}>Unit</th>
                      <th style={{ padding: '8px 12px' }}>MRP</th>
                      <th style={{ padding: '8px 12px' }}>Selling Price</th>
                      <th style={{ padding: '8px 12px' }}>Stock</th>
                      <th style={{ padding: '8px 12px' }}>Barcode</th>
                    </tr>
                  </thead>
                  <tbody>
                    {parsedRows.map((row, idx) => (
                      <tr key={idx} style={{ borderBottom: '1px solid var(--border)' }}>
                        <td style={{ padding: '8px 12px' }}>
                          {row.isValid ? (
                            <FaCheckCircle color="var(--success)" title="Valid row" />
                          ) : (
                            <FaExclamationCircle color="var(--danger)" title={row.error} />
                          )}
                        </td>
                        <td style={{ padding: '8px 12px', fontWeight: 600 }}>{row.name}</td>
                        <td style={{ padding: '8px 12px', color: 'var(--text-secondary)' }}>{row.category || '—'}</td>
                        <td style={{ padding: '8px 12px', color: 'var(--text-secondary)' }}>{row.brand || '—'}</td>
                        <td style={{ padding: '8px 12px' }}>{row.unit}</td>
                        <td style={{ padding: '8px 12px' }}>₹{row.mrp}</td>
                        <td style={{ padding: '8px 12px', color: 'var(--brand-primary)', fontWeight: 600 }}>₹{row.selling_price}</td>
                        <td style={{ padding: '8px 12px' }}>{row.stock}</td>
                        <td style={{ padding: '8px 12px', fontFamily: 'monospace', color: 'var(--text-muted)' }}>{row.barcode || '—'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="drawer-footer" style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 10 }}>
          <button onClick={onClose} className="btn btn-ghost" disabled={importing}>
            Cancel
          </button>
          <button
            onClick={handleImportSubmit}
            className="btn btn-primary"
            disabled={parsedRows.length === 0 || importing}
            style={{ display: 'flex', alignItems: 'center', gap: 6 }}
          >
            {importing ? 'Importing Products...' : `Import ${parsedRows.length} Products`}
          </button>
        </div>
      </motion.div>
    </div>
  );
};

export default BulkImportModal;
