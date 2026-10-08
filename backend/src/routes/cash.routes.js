import { Router } from 'express';
import cashController from '../controllers/cash.controller.js';
import authenticate from '../middlewares/auth.js';

const router = Router();

router.use(authenticate);

// Periode kas
router.get('/periods', cashController.listPeriods);
router.get('/periods/:id', cashController.getPeriod);
router.get('/periods/:id/checklist', cashController.getChecklist);
router.post('/periods', cashController.createPeriod);
router.patch('/periods/:id', cashController.updatePeriod);
router.delete('/periods/:id', cashController.deletePeriod);

// Cash logs
router.get('/logs', cashController.listLogs);
router.post('/pay', cashController.pay);
router.delete('/logs/:id', cashController.deleteLog);

export default router;
