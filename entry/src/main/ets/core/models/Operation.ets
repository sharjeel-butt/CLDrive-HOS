import { t } from '../i18n/I18n';

export enum OperationType {
  COPY = 'copy',
  MOVE = 'move',
  DELETE = 'delete',
  DOWNLOAD = 'download',
  UPLOAD = 'upload'
}

export enum OperationItemKind {
  FILE = 'file',
  FOLDER = 'folder',
  UNKNOWN = 'unknown'
}

export enum OperationStatus {
  QUEUED = 'queued',
  RUNNING = 'running',
  SUCCESS = 'success',
  FAILED = 'failed',
  CANCELLED = 'cancelled'
}

export interface RetryPayload {
  itemId?: string;
  parentId?: string;
  localUri?: string;
  targetFolderId?: string;
  finalName?: string;
  targetUri?: string;
}

export interface Operation {
  id: string;
  type: OperationType;
  itemName: string;
  itemId: string;
  itemKind: OperationItemKind;
  status: OperationStatus;
  progress: number;
  startedAt: number;
  completedAt: number;
  batchIndex: number;
  batchTotal: number;
  errorMessage: string;
  retryPayload?: RetryPayload;
  isRetry: boolean;
}

export function createOperation(
  id: string,
  type: OperationType,
  itemName: string,
  itemId: string,
  itemKind: OperationItemKind,
  batchIndex: number,
  batchTotal: number,
  retryPayload?: RetryPayload
): Operation {
  return {
    id,
    type,
    itemName,
    itemId,
    itemKind,
    status: OperationStatus.QUEUED,
    progress: -1,
    startedAt: Date.now(),
    completedAt: 0,
    batchIndex,
    batchTotal,
    errorMessage: '',
    retryPayload,
    isRetry: false
  };
}

export function operationTypeLabel(type: OperationType): string {
  switch (type) {
    case OperationType.COPY: return t('fb.copy');
    case OperationType.MOVE: return t('fb.move');
    case OperationType.DELETE: return t('fb.delete');
    case OperationType.DOWNLOAD: return t('fb.download');
    case OperationType.UPLOAD: return t('fb.uploadFile');
    default: return '';
  }
}

export function operationStatusLabel(status: OperationStatus): string {
  switch (status) {
    case OperationStatus.QUEUED: return t('fb.queued');
    case OperationStatus.RUNNING: return t('fb.inProgress');
    case OperationStatus.SUCCESS: return t('fb.done');
    case OperationStatus.FAILED: return t('fb.failed');
    case OperationStatus.CANCELLED: return t('fb.cancelled');
    default: return '';
  }
}

export function isActiveStatus(status: OperationStatus): boolean {
  return status === OperationStatus.QUEUED || status === OperationStatus.RUNNING;
}

export function isFinishedStatus(status: OperationStatus): boolean {
  return status === OperationStatus.SUCCESS
    || status === OperationStatus.FAILED
    || status === OperationStatus.CANCELLED;
}

export function canRetry(op: Operation): boolean {
  if (op.status !== OperationStatus.FAILED
    && op.status !== OperationStatus.CANCELLED) {
    return false;
  }
  return op.retryPayload !== undefined;
}