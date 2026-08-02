export interface DataEnvelope<T> {
  data: T;
}

export interface ListEnvelope<T> {
  data: T[];
  meta: {
    page: number;
    limit: number;
    total: number;
  };
}
