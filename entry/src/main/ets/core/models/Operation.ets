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
}

export function createOperation(
  id: string,
  type: OperationType,
  itemName: string,
  itemId: string,
  itemKind: OperationItemKind,
  batchIndex: number,
  batchTotal: number
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
    errorMessage: ''
  };
}

export function operationTypeLabel(type: OperationType): string {
  switch (type) {
    case OperationType.COPY: return 'Copy';
    case OperationType.MOVE: return 'Move';
    case OperationType.DELETE: return 'Delete';
    case OperationType.DOWNLOAD: return 'Download';
    case OperationType.UPLOAD: return 'Upload';
    default: return 'Operation';
  }
}

export function operationTypeIcon(type: OperationType): string {
  switch (type) {
    case OperationType.COPY: return '⧉';
    case OperationType.MOVE: return '→';
    case OperationType.DELETE: return '🗑';
    case OperationType.DOWNLOAD: return '⬇';
    case OperationType.UPLOAD: return '⬆';
    default: return '•';
  }
}

export function operationStatusLabel(status: OperationStatus): string {
  switch (status) {
    case OperationStatus.QUEUED: return 'Queued';
    case OperationStatus.RUNNING: return 'In progress';
    case OperationStatus.SUCCESS: return 'Done';
    case OperationStatus.FAILED: return 'Failed';
    case OperationStatus.CANCELLED: return 'Cancelled';
    default: return '';
  }
}

export function operationItemKindIcon(kind: OperationItemKind): string {
  switch (kind) {
    case OperationItemKind.FOLDER: return '📁';
    case OperationItemKind.FILE: return '📄';
    default: return '•';
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